import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/podia_orb.dart';
import '../../data/app_database.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../voice/voice_screen.dart';
import 'chat_controller.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.conversationId, this.initialPrompt, this.initialImages = const []});
  final int? conversationId;
  final String? initialPrompt;
  final List<String> initialImages;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _ctrl;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = ChatController(
      db: context.read<AppDatabase>(),
      ai: context.read<AiClient>(),
      settings: context.read<SettingsService>(),
      user: context.read<AuthService>().user!,
      conversationId: widget.conversationId,
    );
    _ctrl.load().then((_) {
      if (widget.initialPrompt != null || widget.initialImages.isNotEmpty) {
        _ctrl.send(widget.initialPrompt ?? '', images: widget.initialImages);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _voice() async {
    final text = await Navigator.of(context).push<String>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const VoiceScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
              scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: c),
        ),
      ),
    );
    if (text != null && text.trim().isNotEmpty) _ctrl.send(text);
  }

  void _more() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatMenu(controller: _ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        layout: GlowLayout.chat,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    GlassIconButton(
                        icon: Icons.chevron_left_rounded, iconSize: 24, onTap: () => Navigator.of(context).maybePop()),
                    Expanded(child: Center(child: Text('Chatpodia', style: AppText.title))),
                    GlassIconButton(icon: Icons.more_horiz_rounded, iconSize: 20, onTap: _more),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: _ctrl,
                  builder: (context, _) {
                    final msgs = _ctrl.messages;
                    final items = msgs.length + 1; // + welcome bubble
                    return ListView.builder(
                      reverse: true,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      itemCount: items,
                      itemBuilder: (context, rev) {
                        final i = items - 1 - rev;
                        if (i == 0) return const Padding(padding: EdgeInsets.only(bottom: 22), child: _WelcomeBubble());
                        final mi = i - 1;
                        final m = msgs[mi];
                        final next = mi + 1 < msgs.length ? msgs[mi + 1] : null;
                        final gap = next == null ? 0.0 : (next.role == m.role ? 10.0 : 24.0);
                        final prev = mi > 0 ? msgs[mi - 1] : null;
                        final showTime = prev == null || m.createdAt.difference(prev.createdAt).inMinutes >= 15;
                        return Padding(
                          key: ValueKey(m.id ?? 'tmp$mi'),
                          padding: EdgeInsets.only(bottom: gap),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            if (showTime) TimeSeparator(m.createdAt),
                            MessageBubble(
                              message: m,
                              controller: _ctrl,
                              isActive: _ctrl.activeIndex == mi,
                              isLast: mi == msgs.length - 1,
                              onSuggestion: (t) => _ctrl.send(t),
                            ),
                          ]),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12 + bottom),
                child: ListenableBuilder(
                  listenable: _ctrl,
                  builder: (_, __) => Composer(
                    controller: _input,
                    busy: _ctrl.busy,
                    onSend: (t, imgs) => _ctrl.send(t, images: imgs),
                    onStop: _ctrl.stop,
                    onVoice: _voice,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeBubble extends StatelessWidget {
  const _WelcomeBubble();

  @override
  Widget build(BuildContext context) {
    return MessageEntrance(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PodiaAvatar(size: 30),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiquidGlass(
                  borderRadius: BorderRadius.circular(Insets.radiusBubble),
                  tint: const Color(0x1FFFFFFF),
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
                  child: Text('How can I assist you today?', style: AppText.body.copyWith(fontSize: 13.5)),
                ),
                Transform.translate(
                  offset: const Offset(10, -7),
                  child: Wrap(spacing: 6, children: [
                    GlassChip(
                        dense: true,
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onTap: () => showGlassToast(context, 'Copied')),
                    GlassChip(
                        dense: true,
                        icon: Icons.reply_rounded,
                        label: 'Share',
                        onTap: () => SharePlus.instance.share(ShareParams(text: 'How can I assist you today?'))),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMenu extends StatelessWidget {
  const _ChatMenu({required this.controller});
  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final settings = context.watch<SettingsService>();
    Widget item(IconData icon, String label, VoidCallback onTap, {Color? color, Widget? trailing}) => Pressable(
          scale: 0.98,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
            child: Row(children: [
              Icon(icon, size: 19, color: color ?? AppColors.textPrimary),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppText.body.copyWith(color: color))),
              if (trailing != null) trailing,
            ]),
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LiquidGlass(
          tint: const Color(0xCC10252C),
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              item(Icons.record_voice_over_rounded, 'Read replies aloud',
                  () => settings.update(speakReplies: !settings.speakReplies),
                  trailing: Switch.adaptive(
                    value: settings.speakReplies,
                    activeTrackColor: AppColors.accent,
                    onChanged: (v) => settings.update(speakReplies: v),
                  )),
              if (controller.conversationId != null)
                item(Icons.drive_file_rename_outline_rounded, 'Rename', () async {
                  Navigator.pop(context);
                  final c = TextEditingController(text: controller.title);
                  final t = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.bgElevated,
                      title: Text('Rename chat', style: AppText.title),
                      content: TextField(controller: c, autofocus: true, style: AppText.body),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
                      ],
                    ),
                  );
                  if (t != null) controller.rename(t);
                }),
              item(Icons.description_outlined, 'Export as Markdown', () async {
                Navigator.pop(context);
                final f = await controller.exportMarkdown();
                await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: controller.title));
              }),
              item(Icons.ios_share_rounded, 'Share conversation', () {
                final t = controller.messages
                    .where((m) => m.content.isNotEmpty)
                    .map((m) => '${m.isUser ? 'You' : 'Podia'}: ${m.content}')
                    .join('\n\n');
                Navigator.pop(context);
                SharePlus.instance
                    .share(ShareParams(text: t.isEmpty ? 'Empty conversation' : t, subject: controller.title));
              }),
              if (controller.conversationId != null)
                item(Icons.push_pin_outlined, 'Pin conversation', () async {
                  await db.conversations.setPinned(controller.conversationId!, true);
                  if (context.mounted) Navigator.pop(context);
                }),
              if (controller.conversationId != null)
                item(Icons.delete_outline_rounded, 'Delete conversation', () async {
                  await db.conversations.delete(controller.conversationId!);
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  }
                }, color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }
}
