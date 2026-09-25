import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'fluid_canvas_painter.dart';

/// A single background readiness check the splash screen waits on before
/// transitioning to the dashboard. Real wiring (storage permission check,
/// Isar box open, audio_service init) plugs in via [run].
class SplashSystemCheck {
  final String label;
  final Future<void> Function() run;
  const SplashSystemCheck({required this.label, required this.run});
}

class SplashScreen extends StatefulWidget {
  final List<SplashSystemCheck> systemChecks;
  final VoidCallback onComplete;

  const SplashScreen({
    super.key,
    required this.systemChecks,
    required this.onComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _canvasController;
  late final AnimationController _entranceController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _signatureOpacity;

  double _checkProgress = 0.0;
  String _statusLabel = 'Initializing';

  @override
  void initState() {
    super.initState();

    _canvasController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: AppTokens.entrance),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _signatureOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
    _runSystemChecks();
  }

  Future<void> _runSystemChecks() async {
    final checks = widget.systemChecks;
    final total = checks.isEmpty ? 1 : checks.length;

    for (var i = 0; i < checks.length; i++) {
      if (!mounted) return;
      setState(() => _statusLabel = checks[i].label);

      try {
        await checks[i].run();
      } catch (_) {
        // A failed individual check must not hang the splash indefinitely;
        // surfacing/retry UX for permission denials is handled downstream
        // in the dashboard's empty-state, not here.
      }

      if (!mounted) return;
      setState(() => _checkProgress = (i + 1) / total);
    }

    if (!mounted) return;
    setState(() => _statusLabel = 'Ready');
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _canvasController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AccentScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _canvasController,
            builder: (context, _) => CustomPaint(
              painter: FluidCanvasPainter(t: _canvasController.value, accent: accent),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: const _CraunchMark(size: 96),
                  ),
                ),
                const SizedBox(height: 18),
                FadeTransition(
                  opacity: _logoOpacity,
                  child: Text(
                    'CRaunch Player',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _signatureOpacity,
                  child: Text(
                    'Founded by Chakar Randhawa',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 0.6,
                        ),
                  ),
                ),
                const Spacer(flex: 3),
                _ProgressTracker(progress: _checkProgress, label: _statusLabel, accent: accent),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hand-drawn wordmark glyph — a stylized waveform "C" — built entirely from
/// [CustomPainter] paths so no image or font-icon asset is required.
class _CraunchMark extends StatelessWidget {
  final double size;
  const _CraunchMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 * 0.82;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppColors.accentDefault, AppColors.accentSecondaryDefault, AppColors.accentDefault],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Open ring (C shape): sweep 300 degrees, leaving a 60 degree gap.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.15,
      math.pi * 1.7,
      false,
      ring,
    );

    // Inner waveform bars representing the "audio" half of the mark.
    final barPaint = Paint()..color = Colors.white;
    final barCount = 5;
    final barAreaWidth = radius * 0.9;
    final heights = [0.35, 0.65, 1.0, 0.55, 0.3];
    for (int i = 0; i < barCount; i++) {
      final x = center.dx - barAreaWidth / 2 + (barAreaWidth / (barCount - 1)) * i;
      final h = radius * 0.7 * heights[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, center.dy), width: size.shortestSide * 0.06, height: h),
        Radius.circular(size.shortestSide * 0.03),
      );
      canvas.drawRRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}

class _ProgressTracker extends StatelessWidget {
  final double progress;
  final String label;
  final AppAccent accent;

  const _ProgressTracker({
    required this.progress,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 3,
              child: Stack(
                children: [
                  Container(color: Colors.white.withOpacity(0.08)),
                  AnimatedFractionallySizedBox(
                    duration: AppTokens.microInteraction,
                    curve: AppTokens.entrance,
                    widthFactor: progress.clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accent.primary, accent.secondary]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: AppTokens.microInteraction,
            child: Text(
              label,
              key: ValueKey(label),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.45),
                    letterSpacing: 0.8,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
