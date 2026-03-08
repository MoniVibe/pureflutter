import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared visual shell for game screens.
class GameBackdrop extends StatelessWidget {
  const GameBackdrop({
    required this.child,
    this.backgroundAssetPath,
    this.fallbackColor = const Color(0xFF101A26),
    super.key,
  });

  final Widget child;
  final String? backgroundAssetPath;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF0D1B2A),
                  Color(0xFF1B263B),
                  Color(0xFF202E44),
                ],
              ),
            ),
            child: backgroundAssetPath == null
                ? ColoredBox(color: fallbackColor.withValues(alpha: 0.12))
                : Image.asset(
                    backgroundAssetPath!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: fallbackColor),
                  ),
          ),
        ),
        const _AmbientBlurBlob(
          top: -140,
          left: -120,
          size: 320,
          color: Color(0xAA2B7FFF),
        ),
        const _AmbientBlurBlob(
          top: -60,
          right: -80,
          size: 260,
          color: Color(0xAA3CD3A6),
        ),
        const _AmbientBlurBlob(
          bottom: -170,
          right: -120,
          size: 340,
          color: Color(0xAAEFB54F),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.03),
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const <double>[0, 0.45, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _AmbientBlurBlob extends StatelessWidget {
  const _AmbientBlurBlob({
    required this.size,
    required this.color,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  final double size;
  final Color color;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: SizedBox.square(dimension: size),
          ),
        ),
      ),
    );
  }
}
