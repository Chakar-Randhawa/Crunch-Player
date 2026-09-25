import 'dart:async';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';

import 'scan_config.dart';
import 'scan_progress.dart';
import 'scanner_isolate.dart';

/// The single entry point the rest of the app uses to trigger a library
/// scan. Owns the isolate's lifecycle so callers never touch SendPort/
/// ReceivePort plumbing directly.
class StorageScanner {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamController<ScanProgress>? _controller;

  bool get isScanning => _isolate != null;

  /// Starts a scan of [rootPaths] and returns a broadcast stream of
  /// progress updates that closes itself when the scan reaches
  /// [ScanPhase.complete] or [ScanPhase.error]. Calling this while a scan
  /// is already running throws — callers should check [isScanning] or
  /// await the previous stream's completion first.
  Stream<ScanProgress> startScan(
    List<String> rootPaths, {
    ScanConfig config = const ScanConfig(),
  }) {
    if (isScanning) {
      throw StateError('A scan is already in progress.');
    }

    final controller = StreamController<ScanProgress>.broadcast();
    _controller = controller;

    unawaited(_spawnAndListen(rootPaths, config, controller));

    return controller.stream;
  }

  Future<void> _spawnAndListen(
    List<String> rootPaths,
    ScanConfig config,
    StreamController<ScanProgress> controller,
  ) async {
    final receivePort = ReceivePort();
    _receivePort = receivePort;

    final docsDir = await getApplicationDocumentsDirectory();

    final request = ScanRequest(
      rootPaths: rootPaths,
      isarDirectoryPath: docsDir.path,
      scanConfigJson: config.toJson(),
      replyPort: receivePort.sendPort,
    );

    receivePort.listen((message) {
      if (message is ScanProgress) {
        controller.add(message);
        if (message.phase == ScanPhase.complete || message.phase == ScanPhase.error) {
          _teardown();
          controller.close();
        }
        return;
      }

      // Isolate.spawn's onError port delivers [errorString, stackTrace]
      // when the isolate throws an uncaught exception; onExit delivers a
      // bare null when the isolate terminates for any reason. Either one
      // arriving here (instead of a ScanProgress) means the isolate died
      // without going through the normal complete/error path in
      // scanner_isolate.dart, so this is the fallback that guarantees the
      // stream still closes rather than hanging forever.
      if (controller.isClosed) return;
      if (message is List && message.isNotEmpty) {
        controller.add(ScanProgress(phase: ScanPhase.error, errorMessage: message.first.toString()));
      } else {
        controller.add(const ScanProgress(
          phase: ScanPhase.error,
          errorMessage: 'Scan isolate exited unexpectedly.',
        ));
      }
      _teardown();
      controller.close();
    });

    try {
      _isolate = await Isolate.spawn(
        scannerIsolateEntryPoint,
        request,
        onError: receivePort.sendPort,
        onExit: receivePort.sendPort,
      );
    } catch (e) {
      controller.add(ScanProgress(phase: ScanPhase.error, errorMessage: e.toString()));
      _teardown();
      await controller.close();
    }
  }

  /// Kills the running scan isolate immediately. The in-flight batch that
  /// hadn't yet been flushed to Isar is lost, but everything already
  /// committed in prior batches remains — a subsequent scan simply
  /// upserts over the same paths via the unique filePath index.
  Future<void> cancel() async {
    if (_isolate == null) return;
    _isolate!.kill(priority: Isolate.immediate);
    _controller?.add(const ScanProgress(phase: ScanPhase.error, errorMessage: 'Scan cancelled.'));
    await _controller?.close();
    _teardown();
  }

  void _teardown() {
    _receivePort?.close();
    _receivePort = null;
    _isolate = null;
    _controller = null;
  }
}
