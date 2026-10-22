import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../services/auth_service.dart';
import '../chat/chat_screen.dart';
import '../chat/widgets/composer.dart';
import '../history/history_drawer.dart';
import '../settings/settings_screen.dart';
import '../voice/voice_screen.dart';

class Topic {
  const Topic(this.icon, this.title, this.prompt);
  final IconData icon;
  final String title;
  final String prompt;
}

const kTopics = <Topic>[
  Topic(Icons.auto_fix_high_rounded, 'Recommendations yoga poses',
      'Recommend 6 beginner yoga poses with benefits and how long to hold each.'),
  Topic(Icons.add_photo_alternate_outlined, 'A very useful travel kit for traveling',
      'Make a checklist for a very useful travel kit for traveling.'),
  Topic(Icons.web_rounded, 'Build a pomodoro timer web app',
      'Build a beautiful pomodoro timer web app with start, pause and reset.'),
  Topic(Icons.movie_creation_outlined, 'Make a clip of the northern lights',
      'Make a short video of the northern lights over snowy mountains.'),
  Topic(Icons.psychology_alt_outlined, 'Explain quantum computing simply',
      'Explain quantum computing like I am 12, with an analogy.'),
  Topic(Icons.flight_takeoff_rounded, 'Plan a 3-day trip to Rome',
      'Plan a 3-day itinerary for Rome with food spots each day.'),
  Topic(Icons.palette_outlined, 'Design a minimalist logo',
      'Generate an image of a minimalist mint green logo for an AI app called Podia, flat vector'),
  Topic(Icons.restaurant_menu_rounded, 'Healthy meal ideas for the week',
      'Give me 7 healthy dinner ideas for the week with prep time.'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _input = TextEditingController();
  final _focus = FocusNode();

  void _open({String? prompt, int? conversationId, List<String> images = const []}) {
    _focus.unfocus();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(initialPrompt: prompt, initialImages: images, conversationId: conversationId),
    ));
  }

  void _prefill(String text) {
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
  }

  Future<void> _voice() async {
    final text = await Navigator.of(context).push<String>(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => const VoiceScreen(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
    if (text != null && text.trim().isNotEmpty) _open(prompt: text);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Hi';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Hi';
    return 'Good evening';
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      key: _scaffold,
      resizeToAvoidBottomInset: true,
      drawer: HistoryDrawer(onOpen: (id) => _open(conversationId: id), onNew: () => _open()),
      drawerScrimColor: Colors.black54,
      body: AppBackground(
        layout: GlowLayout.home,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Row(children: [
                  GlassIconButton(
                      icon: Icons.notes_rounded,
                      size: 36,
                      iconSize: 17,
                      onTap: () => _scaffold.currentState?.openDrawer()),
                  const Spacer(),
                  Pressable(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    child: _Avatar(initials: user?.initials ?? '?', url: user?.avatarUrl),
                  ),
                ]),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            SizedBox(height: c.maxHeight * 0.07),
                            _FadeUp(
                              delay: 0,
                              child: Text(
                                '$_greeting, ${user?.firstName ?? 'there'}!\nHow can I help you?',
                                textAlign: TextAlign.center,
                                style: AppText.display.copyWith(fontSize: 24),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _FadeUp(
                              delay: 80,
                              child: Text('Your smart assistant is ready',
                                  style: AppText.bodyMuted.copyWith(fontSize: 13, color: AppColors.textTertiary)),
                            ),
                            const SizedBox(height: 30),
                            _FadeUp(
                              delay: 160,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  runSpacing: 8,
                                  children: [
                                    GlassChip(
                                        icon: Icons.image_outlined,
                                        label: 'Generate image',
                                        onTap: () => _prefill('Generate an image of ')),
                                    GlassChip(
                                        icon: Icons.nightlight_round,
                                        label: 'Goodnight stories',
                                        onTap: () => _open(prompt: 'Tell me a short, calming goodnight story.')),
                                    GlassChip(
                                        icon: Icons.brush_outlined,
                                        label: 'Creative illustrations',
                                        onTap: () => _prefill('Create an illustration of ')),
                                    GlassChip(
                                        icon: Icons.auto_stories_outlined,
                                        label: 'Inspiring novels',
                                        onTap: () =>
                                            _open(prompt: 'Recommend 5 inspiring novels with a one-line pitch each.')),
                                    GlassChip(
                                        icon: Icons.music_note_rounded,
                                        label: 'Play music',
                                        onTap: () => _open(prompt: 'Recommended music')),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 30),
                            _FadeUp(
                              delay: 240,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(children: [
                                  Text('Popular topics', style: AppText.section.copyWith(fontSize: 14)),
                                  const Spacer(),
                                  Pressable(
                                    onTap: () => _seeAll(context),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text('See all',
                                          style: AppText.caption.copyWith(color: AppColors.textTertiary)),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FadeUp(
                              delay: 300,
                              child: SizedBox(
                                height: 116,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: kTopics.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (_, i) =>
                                      TopicCard(topic: kTopics[i], onTap: () => _open(prompt: kTopics[i].prompt)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottom),
                child: Composer(
                  controller: _input,
                  focusNode: _focus,
                  onSend: (t, imgs) => _open(prompt: t, images: imgs),
                  onVoice: _voice,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _seeAll(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LiquidGlass(
            tint: const Color(0xCC0F2329),
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 14),
                Text('Popular topics', style: AppText.title),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final t in kTopics)
                      TopicCard(
                        topic: t,
                        expand: true,
                        onTap: () {
                          Navigator.pop(ctx);
                          _open(prompt: t.prompt);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TopicCard extends StatelessWidget {
  const TopicCard({super.key, required this.topic, required this.onTap, this.expand = false});
  final Topic topic;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: LiquidGlass(
        width: expand ? null : 118,
        borderRadius: BorderRadius.circular(Insets.radiusCard),
        tint: const Color(0x17FFFFFF),
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LiquidGlass(
              shape: BoxShape.circle,
              width: 34,
              height: 34,
              tint: const Color(0x22FFFFFF),
              child: Icon(topic.icon, size: 16, color: AppColors.textPrimary),
            ),
            const Spacer(),
            Text(topic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: AppColors.textPrimary, fontSize: 11, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.url});
  final String initials;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accentGradient,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        image: url == null ? null : DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: url == null ? Text(initials, style: AppText.small.copyWith(fontWeight: FontWeight.w700)) : null,
    );
  }
}

/// Staggered entrance for the home hero.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.child, required this.delay});
  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 650 + delay),
      curve: Interval(delay / (650 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c)),
      child: child,
    );
  }
}
