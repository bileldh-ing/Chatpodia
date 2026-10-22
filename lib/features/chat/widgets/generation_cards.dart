import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/shimmer_text.dart';
import '../../../data/entities.dart';
import '../../generate/image_viewer_screen.dart';
import '../../generate/web_preview_screen.dart';
import 'message_bubble.dart' show showGlassToast;

/// Animated gradient placeholder shown while something is being generated.
class GeneratingCanvas extends StatefulWidget {
  const GeneratingCanvas({super.key, required this.label, this.progress});
  final String label;
  final double? progress;

  @override
  State<GeneratingCanvas> createState() => _GeneratingCanvasState();
}

class _GeneratingCanvasState extends State<GeneratingCanvas> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final a = _c.value * 2 * math.pi;
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              center: Alignment(math.cos(a) * 0.4, math.sin(a) * 0.4),
              transform: GradientRotation(a),
              colors: const [
                Color(0xFF0F3B36),
                Color(0xFF1E6B5B),
                Color(0xFF2AA683),
                Color(0xFF123F3A),
                Color(0xFF0F3B36)
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(color: Colors.black.withValues(alpha: 0.25)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 26),
                  const SizedBox(height: 10),
                  ShimmerText(widget.label,
                      base: Colors.white54, highlight: Colors.white, style: AppText.small.copyWith(fontSize: 12.5)),
                  if (widget.progress != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.progress,
                          minHeight: 3,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(AppColors.mint),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------------- image

class ImageGenerationCard extends StatefulWidget {
  const ImageGenerationCard({super.key, required this.message});
  final MessageEntity message;

  @override
  State<ImageGenerationCard> createState() => _ImageGenerationCardState();
}

class _ImageGenerationCardState extends State<ImageGenerationCard> {
  int _attempt = 0;
  int _autoRetries = 0;
  Timer? _retry;

  /// Free image tiers are rate-limited (HTTP 402/429): back off and retry
  /// automatically a few times before asking the user.
  void _scheduleRetry() {
    if (_retry != null || _autoRetries >= 3 || !_url.startsWith('http')) return;
    _retry = Timer(Duration(seconds: 15 * (_autoRetries + 1)), () {
      if (!mounted) return;
      setState(() {
        _retry = null;
        _autoRetries++;
        _attempt++;
      });
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  String get _url {
    final u = widget.message.meta['url'] as String? ?? '';
    if (_attempt == 0 || !u.startsWith('http')) return u;
    return u.replaceFirst(RegExp(r'seed=\d+'), 'seed=${u.hashCode.abs() % 99999 + _attempt}');
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.message.meta['prompt'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => ImageViewerScreen(url: _url, prompt: prompt),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          )),
          child: Hero(
            tag: _url,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 240,
                height: 240,
                child: Image(
                  image: appImage(_url),
                  fit: BoxFit.cover,
                  frameBuilder: (_, child, frame, sync) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: frame == null
                        ? const GeneratingCanvas(key: ValueKey('g'), label: 'Painting your image')
                        : KeyedSubtree(key: const ValueKey('i'), child: child),
                  ),
                  errorBuilder: (_, __, ___) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleRetry());
                    if (_autoRetries < 3 && _url.startsWith('http')) {
                      return const GeneratingCanvas(key: ValueKey('busy'), label: 'Servers are busy — retrying');
                    }
                    return Container(
                      color: const Color(0x22FFFFFF),
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                        const SizedBox(height: 8),
                        GlassChip(
                            dense: true,
                            label: 'Try again',
                            icon: Icons.refresh_rounded,
                            onTap: () => setState(() => _attempt++)),
                      ]),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          GlassChip(
            dense: true,
            icon: Icons.open_in_full_rounded,
            label: 'View',
            onTap: () => Navigator.of(context).push(PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) => ImageViewerScreen(url: _url, prompt: prompt),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            )),
          ),
          GlassChip(
              dense: true,
              icon: Icons.reply_rounded,
              label: 'Share',
              onTap: () => SharePlus.instance.share(ShareParams(text: '$prompt\n$_url'))),
          GlassChip(
              dense: true, icon: Icons.casino_outlined, label: 'Variation', onTap: () => setState(() => _attempt++)),
        ]),
      ],
    );
  }
}

// --------------------------------------------------------------------------- web

class WebGenerationCard extends StatelessWidget {
  const WebGenerationCard({super.key, required this.message, required this.thinking, required this.streaming});
  final MessageEntity message;
  final bool thinking;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final html = message.meta['html'] as String?;
    final building = html == null;
    final lines = '\n'.allMatches(message.content).length;
    final prompt = message.meta['prompt'] as String? ?? '';

    return LiquidGlass(
      borderRadius: BorderRadius.circular(Insets.radiusBubble),
      tint: const Color(0x1FFFFFFF),
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: building
                  ? GeneratingCanvas(
                      label: thinking ? 'Planning your app' : 'Writing code · $lines lines',
                      progress: thinking ? null : (lines / 220).clamp(0.05, 0.95),
                    )
                  : _CodePeek(html: html),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.language_rounded, size: 15, color: AppColors.mint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(building ? 'Building web app…' : 'Web app ready',
                          style: AppText.small.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(prompt, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  if (!building) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      GlassChip(
                        dense: true,
                        selected: true,
                        icon: Icons.play_arrow_rounded,
                        label: 'Preview',
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => WebPreviewScreen(html: html, title: prompt))),
                      ),
                      GlassChip(
                        dense: true,
                        icon: Icons.code_rounded,
                        label: 'Copy code',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: html));
                          showGlassToast(context, 'Code copied');
                        },
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodePeek extends StatelessWidget {
  const _CodePeek({required this.html});
  final String html;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1518),
      padding: const EdgeInsets.all(10),
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.transparent],
          stops: [0.55, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: Text(
          html.split('\n').take(9).join('\n'),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: AppColors.mintSoft, height: 1.35),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- motion

/// Plays AI-rendered storyboard frames as a cinematic clip (crossfade + Ken Burns).
class MotionGenerationCard extends StatefulWidget {
  const MotionGenerationCard({super.key, required this.message, this.fullscreen = false});
  final MessageEntity message;
  final bool fullscreen;

  @override
  State<MotionGenerationCard> createState() => _MotionGenerationCardState();
}

class _MotionGenerationCardState extends State<MotionGenerationCard> with SingleTickerProviderStateMixin {
  static const _frameDur = Duration(milliseconds: 2600);
  late final AnimationController _c = AnimationController(vsync: this, duration: _frameDur);
  int _i = 0;
  bool _playing = true;
  bool _precached = false;

  List<String> get _frames => ((widget.message.meta['frames'] as List?) ?? const []).cast<String>();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && _frames.isNotEmpty) {
        setState(() => _i = (_i + 1) % _frames.length);
        _c.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStart();
  }

  @override
  void didUpdateWidget(covariant MotionGenerationCard old) {
    super.didUpdateWidget(old);
    _maybeStart();
  }

  void _maybeStart() {
    if (_frames.isEmpty || _precached) return;
    _precached = true;
    for (final f in _frames) {
      precacheImage(appImage(f), context).catchError((_) {});
    }
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    final w = widget.fullscreen ? MediaQuery.of(context).size.width : 210.0;
    final h = w * 4 / 3;

    if (frames.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(width: w, height: h, child: const GeneratingCanvas(label: 'Directing your clip')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _playing = !_playing);
            _playing ? _c.forward() : _c.stop();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.fullscreen ? 0 : 18),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 900),
                    child: AnimatedBuilder(
                      key: ValueKey(_i),
                      animation: _c,
                      builder: (_, child) {
                        final t = Curves.easeInOut.transform(_c.value);
                        final dir = _i.isEven ? 1 : -1;
                        return Transform.scale(
                          scale: 1.06 + 0.10 * t,
                          child: Transform.translate(offset: Offset(dir * 10 * (t - 0.5), -6 * t), child: child),
                        );
                      },
                      child: Image(
                        image: appImage(frames[_i]),
                        fit: BoxFit.cover,
                        loadingBuilder: (_, c, p) => p == null ? c : const GeneratingCanvas(label: 'Rendering frames'),
                        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black26),
                      ),
                    ),
                  ),
                  // Story-style progress bars.
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        for (var k = 0; k < frames.length; k++)
                          Expanded(
                            child: Container(
                              height: 2.5,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                              alignment: Alignment.centerLeft,
                              child: AnimatedBuilder(
                                animation: _c,
                                builder: (_, __) => FractionallySizedBox(
                                  widthFactor: k < _i ? 1 : (k == _i ? _c.value : 0),
                                  child: Container(
                                      decoration:
                                          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: LiquidGlass(
                      borderRadius: BorderRadius.circular(12),
                      tint: const Color(0x33000000),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('${(_frames.length * _frameDur.inMilliseconds / 1000).toStringAsFixed(0)}s · AI clip',
                            style: AppText.caption.copyWith(color: Colors.white, fontSize: 10)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!widget.fullscreen) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            GlassChip(
              dense: true,
              icon: Icons.fullscreen_rounded,
              label: 'Fullscreen',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: Colors.black,
                  body: Stack(children: [
                    Center(child: MotionGenerationCard(message: widget.message, fullscreen: true)),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: GlassIconButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                      ),
                    ),
                  ]),
                ),
              )),
            ),
            GlassChip(
              dense: true,
              icon: Icons.reply_rounded,
              label: 'Share frames',
              onTap: () => SharePlus.instance.share(ShareParams(text: frames.join('\n'))),
            ),
          ]),
        ],
      ],
    );
  }
}

/// Small helper so unawaited futures don't trigger lints.
void fireAndForget(Future<void> f) => unawaited(f);
