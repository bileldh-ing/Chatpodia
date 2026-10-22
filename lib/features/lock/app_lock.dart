import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/podia_orb.dart';
import '../../services/settings_service.dart';

/// Biometric / device-credential app lock. Re-locks after 30s in background.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child, this.authenticator});
  final Widget child;

  /// Injectable for tests; defaults to the platform biometric prompt.
  final Future<bool> Function()? authenticator;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _busy = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!) > const Duration(seconds: 30)) {
        setState(() => _unlocked = false);
        _maybePrompt();
      }
    }
  }

  Future<void> _maybePrompt() async {
    if (!mounted || !context.read<SettingsService>().appLock || _unlocked || _busy) return;
    setState(() => _busy = true);
    bool ok;
    try {
      ok = widget.authenticator != null
          ? await widget.authenticator!()
          : await LocalAuthentication().authenticate(
              localizedReason: 'Unlock Chatpodia',
              options: const AuthenticationOptions(stickyAuth: true),
            );
    } catch (_) {
      ok = false;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _unlocked = ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = context.watch<SettingsService>().appLock && !_unlocked;
    return Stack(children: [
      widget.child,
      IgnorePointer(
        ignoring: !locked,
        child: AnimatedOpacity(
          opacity: locked ? 1 : 0,
          duration: const Duration(milliseconds: 350),
          child: Scaffold(
            body: AppBackground(
              layout: GlowLayout.center,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const PodiaOrb(size: 96),
                  const SizedBox(height: 24),
                  Text('Chatpodia is locked', style: AppText.title),
                  const SizedBox(height: 8),
                  Text('Use your fingerprint, face or PIN', style: AppText.bodyMuted.copyWith(fontSize: 13)),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 200,
                    child: PrimaryButton(
                      label: 'Unlock',
                      loading: _busy,
                      icon: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
                      onTap: _maybePrompt,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
