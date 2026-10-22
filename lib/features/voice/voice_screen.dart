import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/podia_orb.dart';
import '../../core/widgets/shimmer_text.dart';
import '../../services/voice_recognizer.dart';

/// "Podia is listening…" — live speech recognition with a reactive orb.
/// Pops with the final transcript (or null when cancelled).
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> with SingleTickerProviderStateMixin {
  late final VoiceRecognizer _stt = context.read<VoiceRecognizer>();
  late final AnimationController _rings = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  bool _available = false;
  bool _listening = false;
  String _text = '';
  bool _final = false;
  double _level = 0;
  String? _error;
  Timer? _autoSend;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _available = await _stt.initialize(
      onListening: (l) {
        if (mounted) setState(() => _listening = l);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _error = e == 'error_no_match' ? "I didn't catch that. Tap the mic and try again." : 'Microphone error: $e';
        });
      },
    );
    if (!mounted) return;
    if (_available) {
      _start();
    } else {
      setState(() => _error = 'Speech recognition is unavailable. Allow microphone access in Settings.');
    }
  }

  Future<void> _start() async {
    HapticFeedback.mediumImpact();
    _autoSend?.cancel();
    setState(() {
      _error = null;
      _text = '';
      _final = false;
    });
    await _stt.listen(
      onResult: _onResult,
      onLevel: (n) {
        if (mounted) setState(() => _level = n);
      },
    );
  }

  void _onResult(String words, bool isFinal) {
    if (!mounted) return;
    setState(() {
      _text = words;
      _final = isFinal;
    });
    if (isFinal && _text.trim().isNotEmpty) {
      _autoSend = Timer(const Duration(milliseconds: 1100), _send);
    }
  }

  void _send() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(_text.trim().isEmpty ? null : _text.trim());
  }

  Future<void> _toggle() async {
    if (!_available) return _init();
    if (_listening) {
      await _stt.stop();
      if (_text.trim().isNotEmpty) _send();
    } else {
      await _start();
    }
  }

  @override
  void dispose() {
    _autoSend?.cancel();
    _stt.cancel();
    _rings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: AppBackground(
        layout: GlowLayout.center,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(children: [
                  GlassIconButton(
                      icon: Icons.chevron_left_rounded, iconSize: 24, onTap: () => Navigator.of(context).pop()),
                  Expanded(child: Center(child: Text('Chatpodia', style: AppText.title))),
                  const SizedBox(width: 40),
                ]),
              ),
              const Spacer(flex: 2),
              PodiaOrb(size: 150, level: _listening ? _level : 0.15),
              const SizedBox(height: 34),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _error != null
                    ? Padding(
                        key: const ValueKey('e'),
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child:
                            Text(_error!, textAlign: TextAlign.center, style: AppText.bodyMuted.copyWith(fontSize: 13)),
                      )
                    : Row(
                        key: ValueKey(_listening),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShimmerText(
                            _listening ? 'Podia is listening' : (_final ? 'Got it' : 'Tap the mic to talk'),
                            base: AppColors.textSecondary,
                            highlight: AppColors.textPrimary,
                            style: AppText.section.copyWith(fontSize: 14),
                          ),
                          if (_listening)
                            AnimatedEllipsis(
                                style: AppText.section.copyWith(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
              ),
              const Spacer(flex: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: _Transcript(text: _text.isEmpty && _listening ? '' : _text, isFinal: _final),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: EdgeInsets.fromLTRB(40, 0, 40, 28 + bottom),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GlassIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      size: 30,
                      iconSize: 14,
                      tooltip: 'Type instead',
                      onTap: () => Navigator.of(context).pop(_text.trim().isEmpty ? null : _text.trim()),
                    ),
                    _MicButton(listening: _listening, rings: _rings, level: _level, onTap: _toggle),
                    GlassIconButton(
                      icon: Icons.close_rounded,
                      size: 30,
                      iconSize: 14,
                      tooltip: 'Cancel',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spoken words in white, the still-forming tail in grey — as in the mockup.
class _Transcript extends StatelessWidget {
  const _Transcript({required this.text, required this.isFinal});
  final String text;
  final bool isFinal;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox(height: 90);
    final words = text.split(' ');
    final tailCount = isFinal ? 0 : math.min(4, words.length ~/ 2);
    final head = words.sublist(0, words.length - tailCount).join(' ');
    final tail = words.sublist(words.length - tailCount).join(' ');
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: head, style: AppText.transcript),
          if (tail.isNotEmpty)
            TextSpan(text: ' $tail', style: AppText.transcript.copyWith(color: AppColors.textTertiary)),
        ]),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.rings, required this.level, required this.onTap});
  final bool listening;
  final AnimationController rings;
  final double level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: rings,
            builder: (_, __) => CustomPaint(
              size: const Size.square(132),
              painter: _RingsPainter(t: rings.value, active: listening, level: level),
            ),
          ),
          Pressable(
            onTap: onTap,
            scale: 0.9,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.accentGradient,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: listening ? 0.6 : 0.3),
                    blurRadius: listening ? 30 : 16,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Icon(listening ? Icons.mic_rounded : Icons.mic_none_rounded, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.t, required this.active, required this.level});
  final double t;
  final bool active;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // static guide rings (mockup)
    for (final r in [40.0, 52.0, 64.0]) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.accent.withValues(alpha: 0.18 - (r - 40) / 300),
      );
    }
    if (!active) return;
    // expanding pulses
    for (var k = 0; k < 3; k++) {
      final p = (t + k / 3) % 1.0;
      final r = 32 + p * (34 + level * 10);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.mint.withValues(alpha: (1 - p) * 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => true;
}
