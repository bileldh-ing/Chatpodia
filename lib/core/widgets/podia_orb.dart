import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The mint "Podia" orb: a glowing sphere with layered liquid waves.
/// [level] (0..1) drives wave amplitude — wired to mic input on the voice screen.
class PodiaOrb extends StatefulWidget {
  const PodiaOrb({super.key, this.size = 150, this.level = 0.0, this.active = true, this.glow = true});
  final double size;
  final double level;
  final bool active;
  final bool glow;

  @override
  State<PodiaOrb> createState() => _PodiaOrbState();
}

class _PodiaOrbState extends State<PodiaOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  double _smooth = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          _smooth += (widget.level - _smooth) * 0.12;
          final breathe = 1 + math.sin(_c.value * 2 * math.pi * 2) * 0.012 + _smooth * 0.05;
          return Transform.scale(
            scale: widget.active ? breathe : 1,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _OrbPainter(t: _c.value, level: widget.active ? _smooth : 0, glow: widget.glow),
            ),
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t, required this.level, required this.glow});
  final double t;
  final double level;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r);

    if (glow) {
      final gr = Rect.fromCircle(center: c, radius: r * 1.3);
      canvas.drawCircle(
        c,
        r * 1.3,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFF3FE0B0).withValues(alpha: 0.38 + level * 0.2),
            const Color(0xFF3FE0B0).withValues(alpha: 0.0),
          ], stops: const [
            0.55,
            1
          ]).createShader(gr),
      );
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2FD9A8), Color(0xFF55E2BC), Color(0xFFCFF8EA)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );

    final phase = t * 2 * math.pi;
    final amp = r * (0.07 + level * 0.12);
    _wave(canvas, size,
        baseY: 0.50, amp: amp * 1.2, freq: 1.0, phase: phase, color: Colors.white.withValues(alpha: 0.20));
    _wave(canvas, size,
        baseY: 0.58, amp: amp, freq: 1.5, phase: -phase * 1.3 + 1, color: Colors.white.withValues(alpha: 0.26));
    _wave(canvas, size,
        baseY: 0.68, amp: amp * 0.8, freq: 2.0, phase: phase * 2 + 2, color: Colors.white.withValues(alpha: 0.36));

    final hc = Offset(r * 0.62, r * 0.48);
    canvas.drawCircle(
      hc,
      r * 0.75,
      Paint()
        ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: hc, radius: r * 0.75)),
    );
    canvas.restore();

    canvas.drawCircle(
      c,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  void _wave(Canvas canvas, Size s,
      {required double baseY, required double amp, required double freq, required double phase, required Color color}) {
    final path = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width; x += 2) {
      final nx = x / s.width;
      final y = s.height * baseY +
          math.sin(nx * math.pi * 2 * freq + phase) * amp +
          math.sin(nx * math.pi * 4 + phase) * amp * 0.35;
      path.lineTo(x, y);
    }
    path
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}

/// Small orb avatar shown next to assistant messages.
class PodiaAvatar extends StatelessWidget {
  const PodiaAvatar({super.key, this.size = 26, this.thinking = false});
  final double size;
  final bool thinking;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: PodiaOrb(size: size, level: thinking ? 0.9 : 0.1, glow: false));
}
