import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/player/audio_handler_provider.dart';
import '../../core/player/craunch_audio_handler.dart';
import '../../core/scanner/scan_config.dart';
import '../../core/scanner/scan_progress.dart';
import '../../core/scanner/storage_scanner.dart';
import '../../core/sleep_timer/movement_sleep_timer.dart';
import '../../core/theme/app_theme.dart';
import '../player/state/overlay_channel.dart';
import '../player/widgets/edge_glow_overlay.dart';
import 'equalizer_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _crossfadeSeconds = 0.0;
  EdgeGlowStyle _edgeGlowStyle = EdgeGlowStyle.presets.first;
  bool _edgeGlowEnabledInApp = true;
  bool _overlayRunning = false;
  final OverlayChannel _overlayChannel = const OverlayChannel();
  final StorageScanner _storageScanner = StorageScanner();

  SleepTimerState _sleepTimerState = SleepTimerState.off;

  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerProvider);
    handler.sleepTimer.stateStream.listen((state) {
      if (mounted) setState(() => _sleepTimerState = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = AccentScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: 'Playback'),
          _buildCrossfadeTile(accent),
          ListTile(
            leading: const Icon(Icons.equalizer, color: Colors.white70),
            title:
                const Text('Equalizer', style: TextStyle(color: Colors.white)),
            trailing:
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EqualizerScreen()),
            ),
          ),
          const Divider(color: Colors.white12, height: 32),
          _SectionHeader(title: 'Edge Lighting'),
          _buildEdgeGlowStylePicker(accent),
          SwitchListTile(
            value: _edgeGlowEnabledInApp,
            onChanged: (value) => setState(() => _edgeGlowEnabledInApp = value),
            title: const Text('Glow while app is open',
                style: TextStyle(color: Colors.white)),
            activeColor: accent.primary,
          ),
          _buildOverlayTile(accent),
          const Divider(color: Colors.white12, height: 32),
          _SectionHeader(title: 'Sleep Timer'),
          _buildSleepTimerTiles(accent),
          const Divider(color: Colors.white12, height: 32),
          _SectionHeader(title: 'Library'),
          _buildRescanTile(),
          const Divider(color: Colors.white12, height: 32),
          _SectionHeader(title: 'About'),
          const ListTile(
            title: Text('CRaunch Player',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text('Founded by Chakar Randhawa',
                style: TextStyle(color: Colors.white54)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCrossfadeTile(AppAccent accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Crossfade', style: TextStyle(color: Colors.white)),
              Text(
                _crossfadeSeconds == 0
                    ? 'Gapless'
                    : '${_crossfadeSeconds.toStringAsFixed(0)}s',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: 10,
            divisions: 10,
            value: _crossfadeSeconds,
            activeColor: accent.primary,
            onChanged: (value) => setState(() => _crossfadeSeconds = value),
            onChangeEnd: (value) =>
                ref.read(audioHandlerProvider).setCrossfadeSeconds(value),
          ),
          Text(
            _crossfadeSeconds == 0
                ? 'True gapless playback — zero-delay transitions between tracks.'
                : 'Tracks blend into each other over ${_crossfadeSeconds.toStringAsFixed(0)} seconds.',
            style:
                TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeGlowStylePicker(AppAccent accent) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: EdgeGlowStyle.presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final style = EdgeGlowStyle.presets[index];
          final isActive = style.name == _edgeGlowStyle.name;
          return ChoiceChip(
            label: Text(style.name),
            selected: isActive,
            onSelected: (_) {
              setState(() => _edgeGlowStyle = style);
              if (_overlayRunning) _updateOverlayColors(accent);
            },
            selectedColor: accent.primary,
            backgroundColor: AppColors.surfaceDark,
            labelStyle: TextStyle(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), side: BorderSide.none),
          );
        },
      ),
    );
  }

  Widget _buildOverlayTile(AppAccent accent) {
    if (!_overlayChannel.isSupportedPlatform) {
      return ListTile(
        title: const Text('Glow over other apps',
            style: TextStyle(color: Colors.white)),
        subtitle: Text(
          'Not available on this platform — see OverlayChannel\'s doc comment.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
        ),
      );
    }

    return SwitchListTile(
      value: _overlayRunning,
      onChanged: (value) => _toggleOverlay(value, accent),
      title: const Text('Glow over other apps',
          style: TextStyle(color: Colors.white)),
      subtitle: Text(
        'Requires the "draw over other apps" permission.',
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
      ),
      activeColor: accent.primary,
    );
  }

  Future<void> _toggleOverlay(bool enable, AppAccent accent) async {
    if (!enable) {
      await _overlayChannel.stop();
      setState(() => _overlayRunning = false);
      return;
    }

    final hasPermission = await _overlayChannel.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceElevatedDark,
          title: const Text('Permission needed',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Drawing the glow over other apps requires the "draw over other apps" '
            'permission. You\'ll be taken to Settings to grant it.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings')),
          ],
        ),
      );
      if (shouldOpenSettings == true)
        await _overlayChannel.openPermissionSettings();
      return;
    }

    final started = await _overlayChannel.start(
        primary: accent.primary, secondary: accent.secondary);
    setState(() => _overlayRunning = started);
  }

  Future<void> _updateOverlayColors(AppAccent accent) async {
    await _overlayChannel.updateColors(
        primary: accent.primary, secondary: accent.secondary);
  }

  Widget _buildSleepTimerTiles(AppAccent accent) {
    final handler = ref.read(audioHandlerProvider);

    if (_sleepTimerState.mode != SleepTimerMode.off) {
      return ListTile(
        leading: Icon(Icons.bedtime, color: accent.primary),
        title: Text(
          _sleepTimerState.mode == SleepTimerMode.fixedDuration
              ? 'Stopping in ${_sleepTimerState.remaining?.inMinutes ?? 0}m'
              : 'Waiting for stillness'
                  '${_sleepTimerState.fadingOut ? " — fading out" : ""}',
          style: const TextStyle(color: Colors.white),
        ),
        trailing: TextButton(
          onPressed: () => handler.sleepTimer.cancel(),
          child: const Text('Cancel'),
        ),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.timer_outlined, color: Colors.white70),
          title: const Text('Stop after a set time',
              style: TextStyle(color: Colors.white)),
          onTap: () => _showFixedDurationPicker(handler),
        ),
        ListTile(
          leading: const Icon(Icons.vibration, color: Colors.white70),
          title: const Text('Stop when device is still',
              style: TextStyle(color: Colors.white)),
          subtitle: Text(
            'Detects when the phone stops moving (e.g. set down for the night) '
            'rather than a fixed countdown.',
            style:
                TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
          onTap: () => handler.sleepTimer.startMovementBased(),
        ),
      ],
    );
  }

  Future<void> _showFixedDurationPicker(CraunchAudioHandler handler) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surfaceElevatedDark,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [15, 30, 45, 60, 90].map((m) {
            return ListTile(
              title: Text('$m minutes',
                  style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, m),
            );
          }).toList(),
        ),
      ),
    );
    if (minutes != null) {
      handler.sleepTimer.startFixedDuration(Duration(minutes: minutes));
    }
  }

  Widget _buildRescanTile() {
    return ListTile(
      leading: const Icon(Icons.refresh, color: Colors.white70),
      title:
          const Text('Rescan library', style: TextStyle(color: Colors.white)),
      subtitle: Text(
        'Re-indexes your music folders for new or changed files.',
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
      ),
      onTap: _triggerRescan,
    );
  }

  Future<void> _triggerRescan() async {
    if (_storageScanner.isScanning) return;

    // A real device-appropriate root path (e.g. from a folder picker or
    // the platform's standard Music directory) belongs here — using
    // '/storage/emulated/0/Music' as the conventional default Android
    // scan root rather than hardcoding a picker UI this settings screen
    // doesn't otherwise need.
    final stream = _storageScanner.startScan(
        const ['/storage/emulated/0/Music'],
        config: const ScanConfig());

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamBuilder<ScanProgress>(
        stream: stream,
        builder: (context, snapshot) {
          final progress = snapshot.data;
          if (progress == null ||
              progress.phase == ScanPhase.complete ||
              progress.phase == ScanPhase.error) {
            if (progress != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context, rootNavigator: true).pop();
              });
            }
          }
          return AlertDialog(
            backgroundColor: AppColors.surfaceElevatedDark,
            title: const Text('Scanning library',
                style: TextStyle(color: Colors.white)),
            content: Text(
              progress == null
                  ? 'Starting…'
                  : '${_phaseLabel(progress.phase)}\n${progress.tracksInserted} tracks found',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        },
      ),
    );
  }

  String _phaseLabel(ScanPhase phase) {
    switch (phase) {
      case ScanPhase.walkingDirectories:
        return 'Walking folders…';
      case ScanPhase.readingTags:
        return 'Reading tags…';
      case ScanPhase.linkingLibrary:
        return 'Linking albums & artists…';
      case ScanPhase.complete:
        return 'Done.';
      case ScanPhase.error:
        return 'Something went wrong.';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8),
      ),
    );
  }
}
