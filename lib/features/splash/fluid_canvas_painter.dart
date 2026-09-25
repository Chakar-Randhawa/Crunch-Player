import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Paints a soft, animated multi-blob gradient field using pure trigonometric
/// paths — no raster assets, no packaged "glow" widgets. [t] is a 0..1
/// animation progress value driven by the splash controller.
class FluidCanvasPainter extends CustomPainter {
  final double t;
  final AppAccent accent;

  FluidCanvasPainter({required this.t, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.34;

    final blobs = <_Blob>[
      _Blob(phase: 0.0, colorT: 0.0, speed: 1.0, radiusScale: 1.0),
      _Blob(phase: math.pi * 2 / 3, colorT: 0.5, speed: 0.75, radiusScale: 0.82),
      _Blob(phase: math.pi * 4 / 3, colorT: 1.0, speed: 1.25, radiusScale: 0.66),
    ];

    for (final blob in blobs) {
      final angle = blob.phase + t * math.pi * 2 * blob.speed;
      final orbit = size.shortestSide * 0.14;
      final origin = center + Offset(math.cos(angle), math.sin(angle) * 0.6) * orbit;
      final radius = baseRadius * blob.radiusScale * (0.9 + 0.1 * math.sin(t * math.pi * 4 + blob.phase));

      final color = Color.lerp(accent.primary, accent.secondary, blob.colorT)!
          .withOpacity(0.28);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0.0)],
        ).createShader(Rect.fromCircle(center: origin, radius: radius))
        ..blendMode = BlendMode.plus;

      canvas.drawPath(_organicBlobPath(origin, radius, t + blob.phase), paint);
    }
  }

  /// Builds a closed path around [origin] whose radius oscillates per-angle
  /// using a small sum of sine harmonics, producing an organic (non-circular)
  /// blob silhouette instead of a plain circle.
  Path _organicBlobPath(Offset origin, double radius, double seed) {
    const segments = 48;
    final path = Path();
    for (int i = 0; i <= segments; i++) {
      final theta = (i / segments) * math.pi * 2;
      final wobble = 1.0 +
          0.08 * math.sin(theta * 3 + seed * math.pi * 2) +
          0.05 * math.sin(theta * 5 - seed * math.pi * 3);
      final r = radius * wobble;
      final point = origin + Offset(math.cos(theta), math.sin(theta)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant FluidCanvasPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.accent.primary != accent.primary ||
      oldDelegate.accent.secondary != accent.secondary;
}

class _Blob {
  final double phase;
  final double colorT;
  final double speed;
  final double radiusScale;
  const _Blob({
    required this.phase,
    required this.colorT,
    required this.speed,
    required this.radiusScale,
  });
}
