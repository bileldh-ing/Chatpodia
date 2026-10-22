import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../data/app_database.dart';
import '../../data/entities.dart';
import '../../services/auth_service.dart';
import '../settings/settings_screen.dart';

/// Glass side drawer: search, new chat, pinned + grouped history (swipe to delete).
class HistoryDrawer extends StatefulWidget {
  const HistoryDrawer({super.key, required this.onOpen, required this.onNew});
  final ValueChanged<int> onOpen;
  final VoidCallback onNew;

  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {
  String _q = '';
  List<ConversationEntity> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;
    final r = await context.read<AppDatabase>().conversations.forUser(user.id!, query: _q);
    if (mounted) {
      setState(() {
        _items = r;
        _loading = false;
      });
    }
  }

  String _bucket(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'Previous 7 days';
    if (diff < 30) return 'Previous 30 days';
    return 'Older';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final db = context.read<AppDatabase>();

    final rows = <Widget>[];
    String? last;
    for (final c in _items) {
      final b = c.pinned ? 'Pinned' : _bucket(c.updatedAt);
      if (b != last) {
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
          child: Text(b, style: AppText.caption.copyWith(color: AppColors.textTertiary)),
        ));
        last = b;
      }
      rows.add(Dismissible(
        key: ValueKey(c.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          decoration:
              BoxDecoration(color: AppColors.danger.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        ),
        onDismissed: (_) async {
          await db.conversations.delete(c.id!);
          _items.remove(c);
          setState(() {});
        },
        child: Pressable(
          scale: 0.98,
          onTap: () {
            Navigator.pop(context);
            widget.onOpen(c.id!);
          },
          onLongPress: () async {
            await db.conversations.setPinned(c.id!, !c.pinned);
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
            child: Row(children: [
              Icon(c.pinned ? Icons.push_pin_rounded : Icons.chat_bubble_outline_rounded,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(c.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontSize: 13.5))),
            ]),
          ),
        ),
      ));
    }

    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.84,
      shape: const RoundedRectangleBorder(),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF12302F).withValues(alpha: 0.92), AppColors.bgDeep.withValues(alpha: 0.94)],
              ),
              border: const Border(right: BorderSide(color: AppColors.glassStroke)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Text('Chats', style: AppText.title.copyWith(fontSize: 20)),
                      const Spacer(),
                      GlassIconButton(
                        icon: Icons.edit_square,
                        size: 36,
                        iconSize: 16,
                        tooltip: 'New chat',
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNew();
                        },
                      ),
                    ]),
                    const SizedBox(height: 14),
                    LiquidGlass(
                      borderRadius: BorderRadius.circular(14),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (v) {
                              _q = v;
                              _load();
                            },
                            style: AppText.body.copyWith(fontSize: 13.5),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Search conversations',
                              hintStyle: AppText.body.copyWith(color: AppColors.textTertiary, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.mint, strokeWidth: 2))
                          : _items.isEmpty
                              ? Center(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.forum_outlined, color: AppColors.textTertiary, size: 32),
                                    const SizedBox(height: 10),
                                    Text(_q.isEmpty ? 'No conversations yet' : 'No matches', style: AppText.bodyMuted),
                                  ]),
                                )
                              : ListView(physics: const BouncingScrollPhysics(), children: rows),
                    ),
                    const Divider(color: AppColors.divider),
                    Pressable(
                      scale: 0.98,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: AppColors.accent,
                            backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                            child: user?.avatarUrl == null
                                ? Text(user?.initials ?? '?',
                                    style: AppText.small.copyWith(fontWeight: FontWeight.w700))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(user?.name ?? '',
                                  style: AppText.small.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(user?.email ?? '',
                                  style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                          const Icon(Icons.settings_outlined, size: 19, color: AppColors.textSecondary),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
