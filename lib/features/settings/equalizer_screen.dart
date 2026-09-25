import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/equalizer/equalizer_controller.dart';
import '../../core/equalizer/equalizer_models.dart';
import '../../core/player/audio_handler_provider.dart';
import '../../core/theme/app_theme.dart';

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    final accent = AccentScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text('Equalizer',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedBuilder(
        animation: handler.equalizer,
        builder: (context, _) {
          final state = handler.equalizer.state;

          if (!state.nativeAttached) {
            return _UnavailableState(accent: accent);
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _EnabledToggle(state: state, controller: handler.equalizer),
              const SizedBox(height: 24),
              _PresetSelector(state: state, controller: handler.equalizer),
              const SizedBox(height: 28),
              Opacity(
                opacity: state.enabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !state.enabled,
                  child:
                      _BandSliders(state: state, controller: handler.equalizer),
                ),
              ),
              const SizedBox(height: 32),
              Opacity(
                opacity: state.enabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !state.enabled,
                  child: _EffectsSection(
                      state: state, controller: handler.equalizer),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  final AppAccent accent;
  const _UnavailableState({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.equalizer,
                size: 48, color: Colors.white.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              'Equalizer unavailable',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This can happen if nothing is currently playing, or — on iOS — '
              'because the native equalizer requires a playback-path integration '
              'that isn\'t wired up yet on this platform.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                  height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnabledToggle extends StatelessWidget {
  final EqualizerState state;
  final EqualizerController controller;
  const _EnabledToggle({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Equalizer',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        Switch(
          value: state.enabled,
          onChanged: (value) => controller.setEnabled(value),
          activeColor: AccentScope.of(context).primary,
        ),
      ],
    );
  }
}

class _PresetSelector extends StatelessWidget {
  final EqualizerState state;
  final EqualizerController controller;
  const _PresetSelector({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final accent = AccentScope.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: EqualizerPreset.all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = EqualizerPreset.all[index];
          final isActive = state.activePresetName == preset.name;
          return ChoiceChip(
            label: Text(preset.name),
            selected: isActive,
            onSelected: (_) => controller.applyPreset(preset),
            selectedColor: accent.primary,
            backgroundColor: AppColors.surfaceDark,
            labelStyle: TextStyle(
              color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18), side: BorderSide.none),
          );
        },
      ),
    );
  }
}

class _BandSliders extends StatelessWidget {
  final EqualizerState state;
  final EqualizerController controller;
  const _BandSliders({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final accent = AccentScope.of(context);
    return SizedBox(
      height: 220,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: state.bands.map((band) {
          return Expanded(
            child: Column(
              children: [
                Text(
                  '${band.gainDb >= 0 ? '+' : ''}${band.gainDb.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 10),
                ),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: accent.primary,
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                        thumbColor: accent.primary,
                      ),
                      child: Slider(
                        min: state.minGainDb,
                        max: state.maxGainDb,
                        value:
                            band.gainDb.clamp(state.minGainDb, state.maxGainDb),
                        onChanged: (value) =>
                            controller.setBandGain(band.index, value),
                      ),
                    ),
                  ),
                ),
                Text(
                  band.displayLabel,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EffectsSection extends StatelessWidget {
  final EqualizerState state;
  final EqualizerController controller;
  const _EffectsSection({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final accent = AccentScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bass Boost',
            style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600)),
        Slider(
          min: 0,
          max: 1000,
          value: state.bassBoostStrength.toDouble(),
          activeColor: accent.primary,
          onChanged: (value) => controller.setBassBoostStrength(value.round()),
        ),
        const SizedBox(height: 12),
        Text(
          'Spatial Widening',
          style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w600),
        ),
        Slider(
          min: 0,
          max: 1000,
          value: state.virtualizerStrength.toDouble(),
          activeColor: accent.primary,
          onChanged: (value) =>
              controller.setVirtualizerStrength(value.round()),
        ),
        const SizedBox(height: 12),
        Text('Reverb Space',
            style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReverbPreset.values.map((preset) {
            final isActive = state.reverbPreset == preset;
            return ChoiceChip(
              label: Text(_reverbLabel(preset)),
              selected: isActive,
              onSelected: (_) => controller.setReverbPreset(preset),
              selectedColor: accent.secondary,
              backgroundColor: AppColors.surfaceDark,
              labelStyle: TextStyle(
                  color:
                      isActive ? Colors.black : Colors.white.withOpacity(0.6),
                  fontSize: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide.none),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _reverbLabel(ReverbPreset preset) {
    switch (preset) {
      case ReverbPreset.none:
        return 'None';
      case ReverbPreset.smallRoom:
        return 'Small Room';
      case ReverbPreset.mediumRoom:
        return 'Medium Room';
      case ReverbPreset.largeRoom:
        return 'Large Room';
      case ReverbPreset.mediumHall:
        return 'Medium Hall';
      case ReverbPreset.largeHall:
        return 'Large Hall';
      case ReverbPreset.plate:
        return 'Plate';
    }
  }
}
