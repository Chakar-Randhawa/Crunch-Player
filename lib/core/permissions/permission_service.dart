import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionOutcome { granted, denied, permanentlyDenied, notApplicable }

/// Centralizes every runtime permission CRaunch Player needs, since the
/// correct permission to request differs by OS and, on Android, by SDK
/// version — logic the splash screen and settings screen would otherwise
/// have to duplicate.
class PermissionService {
  PermissionService({DeviceInfoPlugin? deviceInfoPlugin})
      : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfoPlugin;
  int? _cachedSdkInt;

  /// Storage/media read access, required before the storage scanner can
  /// run at all. On Android 13+ this is READ_MEDIA_AUDIO; on older Android
  /// it's the legacy READ_EXTERNAL_STORAGE; on iOS it's the Apple Music
  /// library permission (on_audio_query's iOS path), requested via the
  /// same permission_handler API surface.
  Future<PermissionOutcome> requestLibraryAccess() async {
    if (Platform.isAndroid) {
      final sdkInt = await _androidSdkInt();
      final permission = sdkInt >= 33 ? Permission.audio : Permission.storage;
      return _request(permission);
    }
    if (Platform.isIOS) {
      return _request(Permission.mediaLibrary);
    }
    return PermissionOutcome.notApplicable;
  }

  /// Additional permission needed specifically for the MP4→MP3 demuxer
  /// feature, which reads video files out of the Photos/gallery app.
  Future<PermissionOutcome> requestVideoGalleryAccess() async {
    if (Platform.isAndroid) {
      final sdkInt = await _androidSdkInt();
      final permission = sdkInt >= 33 ? Permission.videos : Permission.storage;
      return _request(permission);
    }
    if (Platform.isIOS) {
      return _request(Permission.photos);
    }
    return PermissionOutcome.notApplicable;
  }

  Future<PermissionOutcome> requestNotifications() async {
    // Only meaningful on Android 13+ (POST_NOTIFICATIONS); a no-op grant
    // on iOS and older Android, where notification permission is either
    // implicit or handled by a different, audio_service-owned prompt.
    if (Platform.isAndroid) {
      final sdkInt = await _androidSdkInt();
      if (sdkInt < 33) return PermissionOutcome.notApplicable;
      return _request(Permission.notification);
    }
    return PermissionOutcome.notApplicable;
  }

  /// The "draw over other apps" permission backing the System Overlay
  /// Renderer / edge-lighting-while-backgrounded feature. This cannot be
  /// answered through the normal runtime dialog — Android requires
  /// sending the user to a dedicated Settings screen, so this returns
  /// whether it's already granted rather than triggering a request.
  Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    return Permission.systemAlertWindow.isGranted;
  }

  /// Opens the OS settings screen where the overlay permission above must
  /// be granted manually.
  Future<void> openOverlaySettings() => openAppSettings();

  Future<PermissionOutcome> _request(Permission permission) async {
    final status = await permission.request();
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return PermissionOutcome.granted;
      case PermissionStatus.permanentlyDenied:
        return PermissionOutcome.permanentlyDenied;
      default:
        return PermissionOutcome.denied;
    }
  }

  Future<int> _androidSdkInt() async {
    final cached = _cachedSdkInt;
    if (cached != null) return cached;
    final androidInfo = await _deviceInfoPlugin.androidInfo;
    _cachedSdkInt = androidInfo.version.sdkInt;
    return androidInfo.version.sdkInt;
  }
}
