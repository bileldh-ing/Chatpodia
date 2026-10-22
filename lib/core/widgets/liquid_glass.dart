import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Liquid-glass surface: backdrop blur + saturated tint, a light-catching
/// gradient rim, and a soft specular sheen across the top edge.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(Insets.radiusCard)),
    this.padding,
    this.blur = 22,
    this.tint = AppColors.glassFill,
    this.strokeOpacity = 1,
    this.shape = BoxShape.rectangle,
    this.width,
    this.height,
    this.sheen = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color tint;
  final double strokeOpacity;
  final BoxShape shape;
  final double? width;
  final double? height;
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final circle = shape == BoxShape.circle;
    final radius = circle ? null : borderRadius;

    final content = BackdropFilter(
      filter: ImageFilter.compose(
        outer: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        inner: const ColorFilter.matrix(_saturate),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: (tint.a * 1.35).clamp(0.0, 1.0)),
              tint,
              tint.withValues(alpha: tint.a * 0.6),
            ],
          ),
        ),
        child: Stack(
          children: [
            if (sheen)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: shape,
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.white.withValues(alpha: 0.07),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ],
        ),
      ),
    );

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        foregroundPainter: _GlassRimPainter(radius: radius, circle: circle, opacity: strokeOpacity),
        child: circle ? ClipOval(child: content) : ClipRRect(borderRadius: borderRadius, child: content),
      ),
    );
  }

  // Slight saturation boost so colours behind glass glow through.
  static const List<double> _saturate = [
    1.18, -0.12, -0.06, 0, 0, //
    -0.06, 1.12, -0.06, 0, 0, //
    -0.06, -0.12, 1.18, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({this.radius, required this.circle, required this.opacity});
  final BorderRadius? radius;
  final bool circle;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.32 * opacity),
          Colors.white.withValues(alpha: 0.06 * opacity),
          Colors.white.withValues(alpha: 0.03 * opacity),
          Colors.white.withValues(alpha: 0.16 * opacity),
        ],
        stops: const [0, 0.35, 0.7, 1],
      ).createShader(rect);
    final inset = rect.deflate(0.5);
    if (circle) {
      canvas.drawOval(inset, paint);
    } else {
      canvas.drawRRect((radius ?? BorderRadius.zero).toRRect(inset), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter old) => old.opacity != opacity || old.radius != radius;
}

/// Springy press feedback used by every tappable glass element.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.95, this.haptic = true});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 420),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Circular glass icon button (back, more, side controls).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, this.onTap, this.size = 40, this.iconSize = 18, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Pressable(
      onTap: onTap,
      child: LiquidGlass(
        shape: BoxShape.circle,
        width: size,
        height: size,
        tint: AppColors.glassFillStrong,
        child: Center(child: Icon(icon, size: iconSize, color: AppColors.textPrimary)),
      ),
    );
    final labelled = Semantics(button: true, label: tooltip ?? _defaultLabel(icon), child: btn);
    return tooltip == null ? labelled : Tooltip(message: tooltip!, child: labelled);
  }

  static String _defaultLabel(IconData i) {
    if (i == Icons.chevron_left_rounded) return 'Back';
    if (i == Icons.more_horiz_rounded) return 'More options';
    if (i == Icons.close_rounded) return 'Close';
    return 'Button';
  }
}

/// Pill chip with leading icon ("Generate image", "Copy", "Share"…).
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.icon, this.onTap, this.dense = false, this.selected = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool dense;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: LiquidGlass(
        borderRadius: BorderRadius.circular(dense ? 10 : Insets.radiusChip),
        tint: selected ? const Color(0x3326B38A) : AppColors.glassFill,
        padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 11, vertical: dense ? 5 : 7.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 12 : 13, color: AppColors.textPrimary),
              SizedBox(width: dense ? 4 : 6),
            ],
            Text(label,
                style: dense
                    ? AppText.caption.copyWith(color: AppColors.textPrimary, fontSize: 10.5)
                    : AppText.small.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

/// The mint gradient send / primary circle.
class AccentCircleButton extends StatelessWidget {
  const AccentCircleButton({super.key, required this.icon, this.onTap, this.size = 44, this.iconSize = 20});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.accentGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1),
        ),
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}

/// Wide primary button (auth flows).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onTap, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: loading ? null : onTap,
      scale: 0.97,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AppColors.accentGradient,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: loading
              ? const SizedBox(
                  key: ValueKey('l'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                )
              : Row(
                  key: const ValueKey('t'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 10)],
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.section.copyWith(color: Colors.white, fontSize: 15.5)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Glass secondary button (e.g. "Continue with Google").
class GlassButton extends StatelessWidget {
  const GlassButton({super.key, required this.label, this.onTap, this.leading, this.loading = false});
  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: loading ? null : onTap,
      scale: 0.97,
      child: LiquidGlass(
        height: 54,
        borderRadius: BorderRadius.circular(18),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(width: 10)],
                    Flexible(
                      child: Text(label,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.section.copyWith(fontSize: 15)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
