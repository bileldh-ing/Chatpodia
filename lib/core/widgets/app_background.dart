import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

enum GlowLayout { home, center, chat }

/// Deep teal backdrop with slowly drifting ambient glows, as in the mockup.
class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.child, this.layout = GlowLayout.home});
  final Widget child;
  final GlowLayout layout;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgBase, AppColors.bgDeep],
            ),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _GlowPainter(_c.value, widget.layout)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.t, this.layout);
  final double t;
  final GlowLayout layout;

  void _glow(Canvas canvas, Offset c, double r, Color color, double opacity) {
    final paint = Paint()
      ..shader = RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, paint);
  }

  @override
  void paint(Canvas canvas, Size s) {
    final a = t * 2 * math.pi;
    final dx = math.sin(a) * 18, dy = math.cos(a) * 14;
    switch (layout) {
      case GlowLayout.home:
        _glow(canvas, Offset(s.width * 0.05 + dx, s.height * 0.02 + dy), s.width * 0.85, AppColors.glowGreen, 0.55);
        _glow(canvas, Offset(s.width * 0.9 - dx, s.height * 0.12), s.width * 0.6, AppColors.glowTeal, 0.35);
        _glow(canvas, Offset(s.width * 0.5, s.height * 1.05 - dy), s.width * 0.8, AppColors.glowTeal, 0.18);
      case GlowLayout.center:
        _glow(canvas, Offset(s.width * 0.5 + dx * .5, s.height * 0.33), s.width * 0.7, AppColors.glowGreen, 0.28);
        _glow(canvas, Offset(s.width * 0.5, s.height * 0.95), s.width * 0.7, AppColors.glowTeal, 0.22);
      case GlowLayout.chat:
        _glow(canvas, Offset(s.width * 0.2 + dx, -s.height * 0.05), s.width * 0.7, AppColors.glowTeal, 0.32);
        _glow(canvas, Offset(s.width * 0.9 - dx, s.height * 1.02 + dy), s.width * 0.75, AppColors.glowGreen, 0.22);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.t != t || old.layout != layout;
}
