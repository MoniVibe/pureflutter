import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared visual shell for game screens: a sleek dark backdrop (deep charcoal
/// to near-black) with faint noise and an optional single-accent glow. No
/// imagery by default — pass [accentGlow] to tint it toward the app's accent.
class GameBackdrop extends StatelessWidget {
  const GameBackdrop({
    required this.child,
    this.backgroundAssetPath,
    this.accentGlow,
    this.fallbackColor = const Color(0xFF101A26),
    super.key,
  });

  final Widget child;

  /// Optional faint image texture. Left null for a pure dark surface; when set
  /// it is rendered at very low opacity so it reads as texture, not a picture.
  final String? backgroundAssetPath;

  /// Optional accent color for a subtle top glow (usually the app's accent).
  final Color? accentGlow;

  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final asset = backgroundAssetPath;
    return Stack(
      children: <Widget>[
        // Base: clean vertical charcoal -> near-black.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF191C23),
                  Color(0xFF101216),
                  Color(0xFF08090C),
                ],
                stops: <double>[0, 0.5, 1],
              ),
            ),
          ),
        ),
        if (accentGlow != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.85),
                  radius: 1.15,
                  colors: <Color>[
                    accentGlow!.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const <double>[0, 1],
                ),
              ),
            ),
          ),
        if (asset != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        // Faint static grain so large dark areas don't read as flat.
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _NoisePainter())),
        ),
        // Gentle bottom vignette for depth.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.28),
                ],
                stops: <double>[0.6, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic seed so the grain is stable across repaints/frames.
    final rng = math.Random(7);
    final paint = Paint();
    final count = ((size.width * size.height) / 900).clamp(120, 1400).toInt();
    for (var i = 0; i < count; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final v = rng.nextDouble();
      paint.color = Colors.white.withValues(alpha: 0.012 + v * 0.02);
      canvas.drawRect(Rect.fromLTWH(dx, dy, 1.2, 1.2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}
