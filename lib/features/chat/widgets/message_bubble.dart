import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/podia_orb.dart';
import '../../../core/widgets/shimmer_text.dart';
import '../../../data/entities.dart';
import '../../../services/prebuilt_answers.dart';
import '../chat_controller.dart';
import 'generation_cards.dart';

/// Entrance animation: rise + fade, used for every new message.
class MessageEntrance extends StatelessWidget {
  const MessageEntrance({super.key, required this.child, this.fromRight = false});
  final Widget child;
  final bool fromRight;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset((fromRight ? 14 : -8) * (1 - v), 16 * (1 - v)),
          child: Transform.scale(
            scale: 0.96 + 0.04 * v,
            alignment: fromRight ? Alignment.bottomRight : Alignment.bottomLeft,
            child: c,
          ),
        ),
      ),
      child: child,
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.controller,
    required this.isActive,
    required this.isLast,
    required this.onSuggestion,
  });

  final MessageEntity message;
  final ChatController controller;
  final bool isActive;
  final bool isLast;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return message.isUser ? _UserBubble(message: message, controller: controller, isLast: isLast) : _assistant(context);
  }

  Widget _assistant(BuildContext context) {
    final thinking = isActive && controller.phase == ResponsePhase.thinking;
    final streaming = isActive && controller.phase == ResponsePhase.streaming;

    Widget body;
    switch (message.kind) {
      case MessageKind.image:
        body = ImageGenerationCard(message: message);
      case MessageKind.web:
        body = WebGenerationCard(message: message, thinking: thinking, streaming: streaming);
      case MessageKind.motion:
        body = MotionGenerationCard(message: message);
      case MessageKind.error:
        body = _ErrorBubble(message: message, onRetry: isLast ? controller.regenerate : null);
      case MessageKind.suggestions:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TextBubble(
                text: message.content, thinking: thinking, streaming: streaming, stages: controller.thinkingStages),
            if (!thinking && !streaming) ...[
              const SizedBox(height: 14),
              QuickRepliesCard(
                title: message.meta['title'] as String? ?? 'Quick reply suggestions',
                items: ((message.meta['items'] as List?) ?? const [])
                    .map((e) => QuickSuggestion.fromJson((e as Map).cast<String, dynamic>()))
                    .toList(),
                onPick: (s) {
                  if (s.url != null) {
                    launchUrl(Uri.parse(s.url!), mode: LaunchMode.externalApplication);
                  } else if (s.prompt != null) {
                    onSuggestion(s.prompt!);
                  }
                },
              ),
            ],
          ],
        );
      case MessageKind.text:
        body = _TextBubble(
            text: message.content, thinking: thinking, streaming: streaming, stages: controller.thinkingStages);
    }

    final showActions = !thinking &&
        !streaming &&
        message.content.isNotEmpty &&
        message.kind != MessageKind.error &&
        message.kind != MessageKind.image;

    return MessageEntrance(
      child: Padding(
        padding: const EdgeInsets.only(right: 34),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: PodiaAvatar(size: 30, thinking: thinking || streaming),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  body,
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: showActions
                        ? Transform.translate(
                            offset: const Offset(10, -7),
                            child: _Actions(message: message, controller: controller, isLast: isLast),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.text, required this.thinking, required this.streaming, required this.stages});
  final String text;
  final bool thinking;
  final bool streaming;
  final List<String> stages;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(Insets.radiusBubble),
      tint: const Color(0x1FFFFFFF),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topLeft,
        curve: Curves.easeOut,
        child: thinking && text.isEmpty
            ? ThinkingStatus(stages: stages)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppMarkdown(text: text),
                  if (streaming) const BlinkingCaret(),
                ],
              ),
      ),
    );
  }
}

class AppMarkdown extends StatelessWidget {
  const AppMarkdown({super.key, required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final body = AppText.body.copyWith(fontSize: 13.5, color: color);
    return MarkdownBody(
      data: text,
      selectable: false,
      softLineBreak: true,
      builders: {'pre': _CodeBlockBuilder()},
      onTapLink: (_, href, __) {
        if (href != null) launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
      },
      styleSheet: MarkdownStyleSheet(
        p: body,
        strong: body.copyWith(fontWeight: FontWeight.w700),
        em: body.copyWith(fontStyle: FontStyle.italic),
        a: body.copyWith(color: AppColors.mint, decoration: TextDecoration.underline),
        listBullet: body,
        h1: AppText.title,
        h2: AppText.title.copyWith(fontSize: 16),
        h3: AppText.section,
        code: body.copyWith(
          fontFamily: 'monospace',
          fontSize: 12.5,
          backgroundColor: const Color(0x22FFFFFF),
          color: AppColors.mintSoft,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0x55000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          border: const Border(left: BorderSide(color: AppColors.mint, width: 3)),
          color: const Color(0x11FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        horizontalRuleDecoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        tableBorder: TableBorder.all(color: AppColors.divider),
        tableBody: body,
        tableHead: body.copyWith(fontWeight: FontWeight.w700),
        pPadding: EdgeInsets.zero,
        blockSpacing: 8,
      ),
    );
  }
}

/// Code blocks with a header bar: language label + one-tap copy.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
      BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    final code = element.textContent.replaceAll(RegExp(r'\n$'), '');
    var lang = 'code';
    final first = element.children?.isNotEmpty == true ? element.children!.first : null;
    if (first is md.Element) {
      final cls = first.attributes['class'];
      if (cls != null && cls.startsWith('language-')) lang = cls.substring(9);
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: const BoxDecoration(
            color: Color(0x14FFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Text(lang, style: AppText.caption.copyWith(fontSize: 10.5)),
            const Spacer(),
            Pressable(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                showGlassToast(context, 'Code copied');
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  const Icon(Icons.copy_rounded, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Copy', style: AppText.caption.copyWith(fontSize: 10.5)),
                ]),
              ),
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Text(code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.mintSoft, height: 1.45)),
        ),
      ]),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.controller, required this.isLast});
  final MessageEntity message;
  final ChatController controller;
  final bool isLast;

  List<String> get _images => ((message.meta['images'] as List?) ?? const []).cast<String>();

  void _menu(BuildContext context) {
    HapticFeedback.mediumImpact();
    final isLastUser = controller.messages.lastWhere((m) => m.isUser, orElse: () => message) == message;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LiquidGlass(
            tint: const Color(0xCC10252C),
            borderRadius: BorderRadius.circular(26),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SheetItem(Icons.copy_rounded, 'Copy', () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.content));
                showGlassToast(context, 'Copied');
              }),
              if (isLastUser && !controller.busy)
                _SheetItem(Icons.edit_rounded, 'Edit & resend', () {
                  Navigator.pop(ctx);
                  _edit(context);
                }),
              _SheetItem(Icons.delete_outline_rounded, 'Delete message', () {
                Navigator.pop(ctx);
                controller.deleteMessage(message);
              }, color: AppColors.danger),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final c = TextEditingController(text: message.content);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: LiquidGlass(
          tint: const Color(0xDD10252C),
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.fromLTRB(18, 18, 10, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit message', style: AppText.title),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              maxLines: 5,
              minLines: 1,
              style: AppText.body,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Send')),
            ]),
          ]),
        ),
      ),
    );
    if (text != null && text.trim().isNotEmpty) controller.editLastAndResend(text);
  }

  @override
  Widget build(BuildContext context) {
    return MessageEntrance(
      fromRight: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 70),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onLongPress: () => _menu(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        for (final p in _images)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image(image: appImage(p), width: 120, height: 120, fit: BoxFit.cover),
                          ),
                      ],
                    ),
                  ),
                CustomPaint(
                  painter: _TailPainter(),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: AppText.body
                          .copyWith(color: AppColors.textOnLight, fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.98,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Row(children: [
            Icon(icon, size: 19, color: color ?? AppColors.textPrimary),
            const SizedBox(width: 14),
            Text(label, style: AppText.body.copyWith(color: color)),
          ]),
        ),
      );
}

/// Centered time separator ("Today · 09:41") between message groups.
class TimeSeparator extends StatelessWidget {
  const TimeSeparator(this.time, {super.key});
  final DateTime time;

  static String format(DateTime t) {
    final now = DateTime.now();
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final d = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (d == 0) return 'Today · $hm';
    if (d == 1) return 'Yesterday · $hm';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[t.month - 1]} ${t.day} · $hm';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
            child: Text(format(time), style: AppText.caption.copyWith(color: AppColors.textTertiary, fontSize: 10.5))),
      );
}

/// iMessage-style tail at the bottom-right of the user bubble.
class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width - 16, s.height - 2)
      ..quadraticBezierTo(s.width - 2, s.height + 1, s.width + 5, s.height + 2)
      ..quadraticBezierTo(s.width - 1, s.height - 5, s.width - 2, s.height - 16)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Actions extends StatelessWidget {
  const _Actions({required this.message, required this.controller, required this.isLast});
  final MessageEntity message;
  final ChatController controller;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isPlain = message.kind == MessageKind.text || message.kind == MessageKind.suggestions;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (isPlain)
          GlassChip(
            dense: true,
            icon: Icons.copy_rounded,
            label: 'Copy',
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              showGlassToast(context, 'Copied to clipboard');
            },
          ),
        GlassChip(
          dense: true,
          icon: Icons.reply_rounded,
          label: 'Share',
          onTap: () => SharePlus.instance.share(ShareParams(text: _shareText())),
        ),
        if (isPlain)
          GlassChip(
              dense: true,
              icon: Icons.volume_up_rounded,
              label: 'Listen',
              onTap: () => controller.speak(message.content)),
        if (isLast) GlassChip(dense: true, icon: Icons.refresh_rounded, label: 'Retry', onTap: controller.regenerate),
      ],
    );
  }

  String _shareText() {
    if (message.kind == MessageKind.web) return (message.meta['html'] as String?) ?? message.content;
    if (message.kind == MessageKind.motion) return ((message.meta['frames'] as List?) ?? []).join('\n');
    final items = (message.meta['items'] as List?)?.map((e) => '• ${(e as Map)['label']}').join('\n');
    return items == null ? message.content : '${message.content}\n$items';
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message, this.onRetry});
  final MessageEntity message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      tint: const Color(0x26FF6B6B),
      borderRadius: BorderRadius.circular(Insets.radiusBubble),
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Flexible(child: Text(message.content, style: AppText.body.copyWith(fontSize: 13))),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GlassChip(dense: true, icon: Icons.refresh_rounded, label: 'Retry', onTap: onRetry),
          ],
        ],
      ),
    );
  }
}

/// "Quick reply suggestions" collapsible card from the mockup.
class QuickRepliesCard extends StatefulWidget {
  const QuickRepliesCard({super.key, required this.title, required this.items, required this.onPick});
  final String title;
  final List<QuickSuggestion> items;
  final ValueChanged<QuickSuggestion> onPick;

  @override
  State<QuickRepliesCard> createState() => _QuickRepliesCardState();
}

class _QuickRepliesCardState extends State<QuickRepliesCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(Insets.radiusBubble),
      tint: const Color(0x1FFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            scale: 0.99,
            onTap: () => setState(() => _open = !_open),
            child: Container(
              color: const Color(0x0FFFFFFF),
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded, size: 15, color: AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(widget.title,
                          style: AppText.small.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5))),
                  AnimatedRotation(
                    turns: _open ? 0 : -0.5,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.items.length; i++) ...[
                          if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.divider),
                          Pressable(
                            scale: 0.98,
                            onTap: () => widget.onPick(widget.items[i]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Row(
                                children: [
                                  Text(widget.items[i].emoji, style: const TextStyle(fontSize: 11)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(widget.items[i].label,
                                        style:
                                            AppText.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5)),
                                  ),
                                  const Icon(Icons.north_east_rounded, size: 12, color: AppColors.textTertiary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

void showGlassToast(BuildContext context, String text) {
  final overlay = Overlay.of(context);
  late OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + 96,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (_, v, c) =>
                Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: 0.9 + 0.1 * v, child: c)),
            child: Material(
              type: MaterialType.transparency,
              child: LiquidGlass(
                borderRadius: BorderRadius.circular(20),
                tint: const Color(0x33FFFFFF),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.mint),
                  const SizedBox(width: 8),
                  Text(text, style: AppText.small),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(e);
  Future.delayed(const Duration(milliseconds: 1500), e.remove);
}
