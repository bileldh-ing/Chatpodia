import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Text with a light sweep passing through it ("Thinking…", "Podia is listening…").
class ShimmerText extends StatefulWidget {
  const ShimmerText(this.text, {super.key, this.style, this.base, this.highlight, this.textAlign});
  final String text;
  final TextStyle? style;
  final Color? base;
  final Color? highlight;
  final TextAlign? textAlign;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.base ?? AppColors.textTertiary;
    final hi = widget.highlight ?? AppColors.textPrimary;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = _c.value * 3 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            colors: [base, hi, base],
            stops: [(v - 0.35).clamp(0.0, 1.0), v.clamp(0.0, 1.0), (v + 0.35).clamp(0.0, 1.0)],
          ).createShader(r),
          child: child,
        );
      },
      child: Text(widget.text, style: widget.style ?? AppText.body, textAlign: widget.textAlign),
    );
  }
}

/// Animated trailing ellipsis.
class AnimatedEllipsis extends StatefulWidget {
  const AnimatedEllipsis({super.key, this.style});
  final TextStyle? style;
  @override
  State<AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<AnimatedEllipsis> {
  int _n = 1;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (mounted) setState(() => _n = _n % 3 + 1);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(width: 18, child: Text('.' * _n, style: widget.style));
}

/// Multi-stage reasoning status with elapsed timer, like a pro assistant.
class ThinkingStatus extends StatefulWidget {
  const ThinkingStatus({super.key, required this.stages});
  final List<String> stages;

  @override
  State<ThinkingStatus> createState() => _ThinkingStatusState();
}

class _ThinkingStatusState extends State<ThinkingStatus> {
  int _i = 0;
  Timer? _stage;
  Timer? _tick;
  final _sw = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _stage = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (mounted && _i < widget.stages.length - 1) setState(() => _i++);
    });
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stage?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = (_sw.elapsedMilliseconds / 1000).toStringAsFixed(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.45), end: Offset.zero).animate(a),
              child: c,
            ),
          ),
          child: ShimmerText(
            widget.stages[_i],
            key: ValueKey(_i),
            style: AppText.body.copyWith(fontWeight: FontWeight.w500, fontSize: 13.5),
          ),
        ),
        const SizedBox(width: 8),
        Text('${secs}s', style: AppText.caption.copyWith(color: AppColors.textTertiary)),
      ],
    );
  }
}

/// Pulsing dot shown at the end of streaming text.
class BlinkingCaret extends StatefulWidget {
  const BlinkingCaret({super.key});
  @override
  State<BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<BlinkingCaret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        child: Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mint,
            boxShadow: [BoxShadow(color: AppColors.mint.withValues(alpha: 0.6), blurRadius: 8)],
          ),
        ),
      );
}
