import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging/app_logger.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../data/app_database.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../chat/widgets/message_bubble.dart' show showGlassToast;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final s = context.watch<SettingsService>();
    final user = auth.user;

    return Scaffold(
      body: AppBackground(
        layout: GlowLayout.chat,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(children: [
                  GlassIconButton(icon: Icons.chevron_left_rounded, iconSize: 24, onTap: () => Navigator.pop(context)),
                  Expanded(child: Center(child: Text('Settings', style: AppText.title))),
                  const SizedBox(width: 40),
                ]),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  children: [
                    // Profile card
                    LiquidGlass(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.accent,
                          backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                          child: user?.avatarUrl == null
                              ? Text(user?.initials ?? '?', style: AppText.title.copyWith(fontSize: 18))
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(user?.name ?? '', style: AppText.section),
                            const SizedBox(height: 2),
                            Text(user?.email ?? '', style: AppText.caption),
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(user?.provider == 'google' ? Icons.g_mobiledata_rounded : Icons.lock_outline_rounded,
                                  size: 14, color: AppColors.mint),
                              const SizedBox(width: 4),
                              Text(user?.provider == 'google' ? 'Signed in with Google' : 'Email & password',
                                  style: AppText.caption.copyWith(color: AppColors.mint)),
                            ]),
                          ]),
                        ),
                        GlassIconButton(
                            icon: Icons.edit_rounded, size: 34, iconSize: 15, onTap: () => _editName(context)),
                      ]),
                    ),
                    _section('AI MODEL'),
                    LiquidGlass(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        for (final p in AiProvider.values)
                          _Tile(
                            icon: switch (p) {
                              AiProvider.pollinations => Icons.cloud_outlined,
                              AiProvider.gemini => Icons.auto_awesome_outlined,
                              AiProvider.openaiCompatible => Icons.hub_outlined,
                            },
                            title: p.label,
                            subtitle: p.subtitle,
                            trailing: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: s.provider == p
                                  ? const Icon(Icons.check_circle_rounded,
                                      key: ValueKey(1), color: AppColors.mint, size: 20)
                                  : const Icon(Icons.circle_outlined,
                                      key: ValueKey(0), color: AppColors.textTertiary, size: 20),
                            ),
                            onTap: () async {
                              await s.update(provider: p);
                              if (!context.mounted) return;
                              if (p == AiProvider.gemini && s.geminiKey.isEmpty) _editGemini(context);
                              if (p == AiProvider.openaiCompatible && s.openaiKey.isEmpty) _editOpenAi(context);
                            },
                          ),
                        if (s.provider == AiProvider.gemini)
                          _Tile(
                            icon: Icons.key_rounded,
                            title: 'Gemini key & model',
                            subtitle: s.geminiKey.isEmpty
                                ? 'Not set'
                                : '••••${s.geminiKey.substring(s.geminiKey.length - 4)} · ${s.geminiModel}',
                            onTap: () => _editGemini(context),
                          ),
                        if (s.provider == AiProvider.openaiCompatible)
                          _Tile(
                            icon: Icons.key_rounded,
                            title: 'Endpoint, key & model',
                            subtitle: '${s.openaiModel} · ${Uri.tryParse(s.openaiBaseUrl)?.host ?? ''}',
                            onTap: () => _editOpenAi(context),
                          ),
                      ]),
                    ),
                    _section('PREFERENCES'),
                    LiquidGlass(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        _Tile(
                          icon: Icons.record_voice_over_outlined,
                          title: 'Read replies aloud',
                          trailing: Switch.adaptive(
                              value: s.speakReplies,
                              activeTrackColor: AppColors.accent,
                              onChanged: (v) => s.update(speakReplies: v)),
                        ),
                        _Tile(
                          icon: Icons.vibration_rounded,
                          title: 'Haptic feedback',
                          trailing: Switch.adaptive(
                              value: s.haptics,
                              activeTrackColor: AppColors.accent,
                              onChanged: (v) => s.update(haptics: v)),
                        ),
                      ]),
                    ),
                    _section('PRIVACY & SECURITY'),
                    LiquidGlass(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        _Tile(
                          icon: Icons.fingerprint_rounded,
                          title: 'App lock',
                          subtitle: 'Fingerprint, face or device PIN',
                          trailing: Switch.adaptive(
                            value: s.appLock,
                            activeTrackColor: AppColors.accent,
                            onChanged: (v) async {
                              if (v) {
                                final la = LocalAuthentication();
                                final ok = await la.isDeviceSupported() &&
                                    await la.authenticate(localizedReason: 'Enable app lock for Chatpodia');
                                if (!ok) {
                                  if (context.mounted) showGlassToast(context, 'App lock not enabled');
                                  return;
                                }
                              }
                              await s.update(appLock: v);
                            },
                          ),
                        ),
                        if (user?.provider == 'password')
                          _Tile(
                              icon: Icons.password_rounded,
                              title: 'Change password',
                              onTap: () => _changePassword(context)),
                        _Tile(
                          icon: Icons.cleaning_services_outlined,
                          title: 'Clear all conversations',
                          onTap: () async {
                            final ok = await _confirm(context, 'Clear all conversations?',
                                'This permanently deletes your chat history on this device.');
                            if (ok && context.mounted) {
                              await context.read<AppDatabase>().conversations.deleteAllForUser(user!.id!);
                              if (context.mounted) showGlassToast(context, 'History cleared');
                            }
                          },
                        ),
                        _Tile(
                          icon: Icons.person_remove_outlined,
                          title: 'Delete account',
                          danger: true,
                          onTap: () async {
                            final ok = await _confirm(context, 'Delete your account?',
                                'Your account and all its data will be erased from this device.');
                            if (ok && context.mounted) {
                              await auth.deleteAccount();
                              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                            }
                          },
                        ),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    GlassButton(
                      label: 'Sign out',
                      leading: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
                      onTap: () async {
                        await auth.signOut();
                        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                    ),
                    _section('ABOUT'),
                    LiquidGlass(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        _Tile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy policy',
                          onTap: () => launchUrl(
                              Uri.parse('https://github.com/bileldh-ing/Chatpodia/blob/main/PRIVACY.md'),
                              mode: LaunchMode.externalApplication),
                        ),
                        _Tile(
                          icon: Icons.bug_report_outlined,
                          title: 'Copy diagnostics',
                          subtitle: 'Recent app logs for bug reports',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: AppLogger.dump()));
                            showGlassToast(context, 'Diagnostics copied');
                          },
                        ),
                        _Tile(
                          icon: Icons.code_rounded,
                          title: 'Source code',
                          onTap: () => launchUrl(Uri.parse('https://github.com/bileldh-ing/Chatpodia'),
                              mode: LaunchMode.externalApplication),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform().catchError((_) =>
                            PackageInfo(appName: 'Chatpodia', packageName: '', version: '1.1.0', buildNumber: '2')),
                        builder: (_, snap) => Text(
                          'Chatpodia ${snap.data?.version ?? ''} (${snap.data?.buildNumber ?? ''})',
                          style: AppText.caption.copyWith(color: AppColors.textTertiary),
                        ),
                      ),
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

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 24, 6, 8),
        child: Text(t, style: AppText.caption.copyWith(letterSpacing: 1.1, color: AppColors.textTertiary)),
      );

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => _GlassDialog(
        title: title,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm', style: TextStyle(color: AppColors.danger))),
        ],
        child: Text(body, style: AppText.bodyMuted),
      ),
    );
    return r ?? false;
  }

  Future<void> _editName(BuildContext context) async {
    final auth = context.read<AuthService>();
    final c = TextEditingController(text: auth.user?.name);
    await showDialog(
      context: context,
      builder: (ctx) => _GlassDialog(
        title: 'Your name',
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await auth.updateName(c.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } on AuthException catch (e) {
                if (ctx.mounted) showGlassToast(ctx, e.message);
              }
            },
            child: const Text('Save'),
          ),
        ],
        child: _Field(controller: c, hint: 'Full name'),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final auth = context.read<AuthService>();
    final cur = TextEditingController();
    final next = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => _GlassDialog(
        title: 'Change password',
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await auth.changePassword(cur.text, next.text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  showGlassToast(context, 'Password updated');
                }
              } on AuthException catch (e) {
                if (ctx.mounted) showGlassToast(ctx, e.message);
              }
            },
            child: const Text('Update'),
          ),
        ],
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Field(controller: cur, hint: 'Current password', obscure: true),
          const SizedBox(height: 10),
          _Field(controller: next, hint: 'New password', obscure: true),
        ]),
      ),
    );
  }

  Future<void> _editGemini(BuildContext context) async {
    final s = context.read<SettingsService>();
    final key = TextEditingController(text: s.geminiKey);
    final model = TextEditingController(text: s.geminiModel);
    await showDialog(
      context: context,
      builder: (ctx) => _GlassDialog(
        title: 'Google Gemini',
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await s.update(geminiKey: key.text, geminiModel: model.text.isEmpty ? 'gemini-2.5-flash' : model.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Field(controller: key, hint: 'API key (aistudio.google.com)', obscure: true),
          const SizedBox(height: 10),
          _Field(controller: model, hint: 'Model, e.g. gemini-2.5-flash'),
        ]),
      ),
    );
  }

  Future<void> _editOpenAi(BuildContext context) async {
    final s = context.read<SettingsService>();
    final url = TextEditingController(text: s.openaiBaseUrl);
    final key = TextEditingController(text: s.openaiKey);
    final model = TextEditingController(text: s.openaiModel);
    await showDialog(
      context: context,
      builder: (ctx) => _GlassDialog(
        title: 'OpenAI-compatible',
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await s.update(openaiBaseUrl: url.text, openaiKey: key.text, openaiModel: model.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Field(controller: url, hint: 'Base URL, e.g. https://api.openai.com/v1'),
          const SizedBox(height: 10),
          _Field(controller: key, hint: 'API key', obscure: true),
          const SizedBox(height: 10),
          _Field(controller: model, hint: 'Model, e.g. gpt-4o-mini'),
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Pressable(
      scale: 0.985,
      onTap: onTap,
      haptic: onTap != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.body.copyWith(color: color, fontSize: 14)),
              if (subtitle != null) Text(subtitle!, style: AppText.caption),
            ]),
          ),
          trailing ??
              (onTap != null
                  ? const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary)
                  : const SizedBox()),
        ]),
      ),
    );
  }
}

class _GlassDialog extends StatelessWidget {
  const _GlassDialog({required this.title, required this.child, required this.actions});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: LiquidGlass(
        tint: const Color(0xDD10252C),
        borderRadius: BorderRadius.circular(26),
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.title),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, this.obscure = false});
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: AppText.body,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppText.body.copyWith(color: AppColors.textTertiary),
        ),
      ),
    );
  }
}
