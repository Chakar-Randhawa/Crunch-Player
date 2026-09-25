import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/library/library_screen.dart';
import 'core/player/craunch_audio_handler.dart';
import 'core/player/audio_handler_provider.dart';
import 'core/permissions/permission_service.dart';
import 'core/database/isar_service.dart';
import 'features/player/state/dynamic_accent_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final audioHandler = await AudioService.init(
    builder: () => CraunchAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.craunch.player.audio',
      androidNotificationChannelName: 'CRaunch Player Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const CraunchPlayerApp(),
    ),
  );
}

class CraunchPlayerApp extends StatefulWidget {
  const CraunchPlayerApp({super.key});

  @override
  State<CraunchPlayerApp> createState() => _CraunchPlayerAppState();
}

class _CraunchPlayerAppState extends State<CraunchPlayerApp> {
  bool _splashComplete = false;
  final DynamicAccentController _accentController = DynamicAccentController();

  // Real checks — storage/media permission (required before the scanner
  // can run at all), opening the Isar database, and the Android 13+
  // notification permission the persistent playback notification depends
  // on. Each is wrapped in try/catch by SplashScreen itself, so a denied
  // permission here doesn't hang app start — it just means the library
  // stays empty until the user grants it from Settings later.
  final PermissionService _permissionService = PermissionService();

  List<SplashSystemCheck> get _systemChecks => [
        SplashSystemCheck(
          label: 'Requesting storage access',
          run: () => _permissionService.requestLibraryAccess(),
        ),
        SplashSystemCheck(
          label: 'Opening local library index',
          run: () => IsarService.instance.open(),
        ),
        SplashSystemCheck(
          label: 'Requesting notification access',
          run: () => _permissionService.requestNotifications(),
        ),
      ];

  @override
  void dispose() {
    _accentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        // Subscribing here (rather than only after splash completes) means
        // the accent is already tracking the audio handler's track stream
        // by the time the library/now-playing screens mount — no first-
        // track flash of the fallback color while a listener spins up.
        return _AccentSubscription(
          audioHandler: ref.watch(audioHandlerProvider),
          controller: _accentController,
          child: ValueListenableBuilder<AppAccent>(
            valueListenable: _accentController,
            builder: (context, targetAccent, child) {
              // TweenAnimationBuilder detects that `tween`'s end value
              // changed on each rebuild and automatically animates from
              // whatever the previously-interpolated AppAccent was toward
              // the new target — a smooth crossfade on every track change,
              // not an abrupt color snap. `begin` only matters for the
              // very first frame, before any animation has run.
              return TweenAnimationBuilder<AppAccent>(
                tween: AppAccentTween(begin: AppAccent.fallback, end: targetAccent),
                duration: AppTokens.routeTransition,
                builder: (context, animatedAccent, child) => AccentScope(
                  accent: animatedAccent,
                  child: child!,
                ),
                child: child,
              );
            },
            child: _buildApp(),
          ),
        );
      },
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'CRaunch Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: _splashComplete
          ? Consumer(
              builder: (context, ref, _) => LibraryScreen(
                onTrackSelected: (track, queue, startIndex) {
                  ref.read(audioHandlerProvider).playTrackWithQueue(queue, startIndex);
                },
              ),
            )
          : SplashScreen(
              systemChecks: _systemChecks,
              onComplete: () => setState(() => _splashComplete = true),
            ),
    );
  }
}

/// Owns the subscription from CraunchAudioHandler's currentTrackStream
/// into DynamicAccentController — split out from the main build method
/// purely so the subscription's lifecycle (start on first build, cancel
/// on dispose) is managed by a StatefulWidget tied to the audioHandler
/// instance rather than re-subscribing on every rebuild of the tree above.
class _AccentSubscription extends StatefulWidget {
  final CraunchAudioHandler audioHandler;
  final DynamicAccentController controller;
  final Widget child;

  const _AccentSubscription({
    required this.audioHandler,
    required this.controller,
    required this.child,
  });

  @override
  State<_AccentSubscription> createState() => _AccentSubscriptionState();
}

class _AccentSubscriptionState extends State<_AccentSubscription> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.audioHandler.currentTrackStream.listen(widget.controller.onTrackChanged);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
