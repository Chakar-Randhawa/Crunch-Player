import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controls the native System Overlay Renderer (Android only — see
/// CraunchOverlayPlugin.kt's doc comment on why iOS has no equivalent
/// here; that platform's version of "glow while backgrounded" is Live
/// Activities, a materially different, ActivityKit-based feature not
/// implemented in this pass).
class OverlayChannel {
  static const MethodChannel _channel =
      MethodChannel('com.craunch.player/overlay');

  const OverlayChannel();

  bool get isSupportedPlatform => Platform.isAndroid;

  Future<bool> hasPermission() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod('openPermissionSettings');
  }

  Future<bool> start({required Color primary, required Color secondary}) async {
    if (!isSupportedPlatform) return false;
    try {
      await _channel.invokeMethod('start', {
        'primaryColorArgb': primary.value,
        'secondaryColorArgb': secondary.value,
      });
      return true;
    } on PlatformException {
      return false;
    }
  }

  Future<void> updateColors(
      {required Color primary, required Color secondary}) async {
    if (!isSupportedPlatform) return;
    try {
      await _channel.invokeMethod('updateColors', {
        'primaryColorArgb': primary.value,
        'secondaryColorArgb': secondary.value,
      });
    } on PlatformException {
      // Updating colors on a not-currently-running overlay is harmless to
      // ignore — the next `start` call will apply the latest colors.
    }
  }

  Future<void> stop() async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod('stop');
  }
}
