import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/podia_orb.dart';
import '../../services/auth_service.dart';

// ============================================================== Splash

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        layout: GlowLayout.center,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, c) => Opacity(opacity: v, child: Transform.scale(scale: 0.85 + 0.15 * v, child: c)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const PodiaOrb(size: 110),
              const SizedBox(height: 26),
              Text('Chatpodia', style: AppText.display.copyWith(fontSize: 28)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================== Welcome / onboarding

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    ('Meet Podia', 'Your smart assistant — ask anything, by text or voice, and get answers that stream in instantly.'),
    ('Create anything', 'Generate images, short motion clips and fully working mini web apps from a single sentence.'),
    ('Private by design', 'Your account and conversations live encrypted on your device. You stay in control.'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: AppBackground(
        layout: GlowLayout.home,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Spacer(flex: 2),
              PodiaOrb(size: 170, level: 0.25 + _page * 0.2),
              const Spacer(flex: 1),
              SizedBox(
                height: 150,
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _pages.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _page = i);
                  },
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(children: [
                      Text(_pages[i].$1, textAlign: TextAlign.center, style: AppText.display),
                      const SizedBox(height: 12),
                      Text(_pages[i].$2, textAlign: TextAlign.center, style: AppText.bodyMuted),
                    ]),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.mint : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              const Spacer(flex: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + bottom),
                child: Column(children: [
                  PrimaryButton(
                    label: 'Get started',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    label: 'I already have an account',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================== Shared pieces

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.password = false,
    this.keyboard,
    this.validator,
    this.onChanged,
    this.action = TextInputAction.next,
    this.onSubmit,
    this.autofill,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool password;
  final TextInputType? keyboard;
  final String? Function(String)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction action;
  final VoidCallback? onSubmit;
  final Iterable<String>? autofill;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _obscure = true;
  bool _touched = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && widget.controller.text.isNotEmpty) setState(() => _touched = true);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _touched ? widget.validator?.call(widget.controller.text) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _focus.hasFocus
                ? [BoxShadow(color: AppColors.mint.withValues(alpha: 0.18), blurRadius: 18, spreadRadius: -2)]
                : null,
          ),
          child: LiquidGlass(
            borderRadius: BorderRadius.circular(16),
            strokeOpacity: _focus.hasFocus ? 2.2 : 1,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Icon(widget.icon, size: 18, color: _focus.hasFocus ? AppColors.mint : AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.password && _obscure,
                  keyboardType: widget.keyboard,
                  textInputAction: widget.action,
                  autofillHints: widget.autofill,
                  autocorrect: !widget.password,
                  enableSuggestions: !widget.password,
                  onChanged: (v) {
                    widget.onChanged?.call(v);
                    if (_touched) setState(() {});
                  },
                  onSubmitted: (_) => widget.onSubmit?.call(),
                  style: AppText.body.copyWith(fontSize: 14.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 17),
                    hintText: widget.hint,
                    hintStyle: AppText.body.copyWith(color: AppColors.textTertiary, fontSize: 14.5),
                  ),
                ),
              ),
              if (widget.password)
                Pressable(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 0, 0),
                  child: Text(error, style: AppText.caption.copyWith(color: AppColors.danger)),
                ),
        ),
      ],
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        layout: GlowLayout.home,
        child: SafeArea(
          child: AutofillGroup(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GlassIconButton(
                      icon: Icons.chevron_left_rounded, iconSize: 24, onTap: () => Navigator.maybePop(context)),
                ),
                const SizedBox(height: 26),
                const Center(child: PodiaOrb(size: 74)),
                const SizedBox(height: 22),
                Text(title, textAlign: TextAlign.center, style: AppText.display),
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center, style: AppText.bodyMuted.copyWith(fontSize: 13.5)),
                const SizedBox(height: 30),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: LiquidGlass(
                tint: const Color(0x26FF6B6B),
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(child: Text(message!, style: AppText.small.copyWith(fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: AppText.caption)),
          const Expanded(child: Divider(color: AppColors.divider)),
        ]),
      );
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w800, fontSize: 14)),
      );
}

Future<void> _googleFlow(BuildContext context, void Function(bool) setLoading, void Function(String?) setError) async {
  setLoading(true);
  setError(null);
  try {
    await context.read<AuthService>().signInWithGoogle();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  } on AuthException catch (e) {
    setError(e.message);
  } finally {
    setLoading(false);
  }
}

// ============================================================== Login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _gLoading = false;
  String? _error;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().signIn(email: _email.text, password: _password.text);
      TextInput.finishAutofillContext();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue with Podia',
      children: [
        _ErrorBanner(_error),
        AuthField(
          controller: _email,
          hint: 'Email',
          icon: Icons.alternate_email_rounded,
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          validator: AuthService.validateEmail,
        ),
        const SizedBox(height: 12),
        AuthField(
          controller: _password,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          password: true,
          autofill: const [AutofillHints.password],
          action: TextInputAction.done,
          onSubmit: _submit,
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Sign in', loading: _loading, onTap: _submit),
        const _OrDivider(),
        GlassButton(
          label: 'Continue with Google',
          leading: const _GoogleLogo(),
          loading: _gLoading,
          onTap: () => _googleFlow(context, (v) => setState(() => _gLoading = v), (e) => setState(() => _error = e)),
        ),
        const SizedBox(height: 26),
        Center(
          child: Pressable(
            onTap: () =>
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RegisterScreen())),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: "Don't have an account? ", style: AppText.bodyMuted.copyWith(fontSize: 13.5)),
              TextSpan(
                  text: 'Create one',
                  style: AppText.body.copyWith(color: AppColors.mint, fontWeight: FontWeight.w600, fontSize: 13.5)),
            ])),
          ),
        ),
      ],
    );
  }
}

// ============================================================== Register

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _gLoading = false;
  bool _agree = true;
  String? _error;
  int _strength = 0;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_agree) {
      setState(() => _error = 'Please accept the terms to continue.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().register(name: _name.text, email: _email.text, password: _password.text);
      TextInput.finishAutofillContext();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
    const colors = [AppColors.danger, AppColors.danger, AppColors.warning, AppColors.mint, AppColors.mint];
    return _AuthScaffold(
      title: 'Create your account',
      subtitle: 'It takes less than a minute',
      children: [
        _ErrorBanner(_error),
        AuthField(
          controller: _name,
          hint: 'Full name',
          icon: Icons.person_outline_rounded,
          autofill: const [AutofillHints.name],
          validator: AuthService.validateName,
        ),
        const SizedBox(height: 12),
        AuthField(
          controller: _email,
          hint: 'Email',
          icon: Icons.alternate_email_rounded,
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          validator: AuthService.validateEmail,
        ),
        const SizedBox(height: 12),
        AuthField(
          controller: _password,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          password: true,
          autofill: const [AutofillHints.newPassword],
          action: TextInputAction.done,
          validator: AuthService.validatePassword,
          onChanged: (v) => setState(() => _strength = AuthService.passwordStrength(v)),
          onSubmit: _submit,
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          opacity: _password.text.isEmpty ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i < _strength ? colors[_strength] : Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            SizedBox(
                width: 62, child: Text(labels[_strength], style: AppText.caption.copyWith(color: colors[_strength]))),
          ]),
        ),
        const SizedBox(height: 12),
        Pressable(
          onTap: () => setState(() => _agree = !_agree),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: _agree ? AppColors.accentGradient : null,
                border: Border.all(color: _agree ? Colors.transparent : Colors.white30),
              ),
              child: _agree ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('I agree to the Terms of Service and Privacy Policy', style: AppText.caption)),
          ]),
        ),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Create account', loading: _loading, onTap: _submit),
        const _OrDivider(),
        GlassButton(
          label: 'Continue with Google',
          leading: const _GoogleLogo(),
          loading: _gLoading,
          onTap: () => _googleFlow(context, (v) => setState(() => _gLoading = v), (e) => setState(() => _error = e)),
        ),
        const SizedBox(height: 26),
        Center(
          child: Pressable(
            onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Already have an account? ', style: AppText.bodyMuted.copyWith(fontSize: 13.5)),
              TextSpan(
                  text: 'Sign in',
                  style: AppText.body.copyWith(color: AppColors.mint, fontWeight: FontWeight.w600, fontSize: 13.5)),
            ])),
          ),
        ),
      ],
    );
  }
}
