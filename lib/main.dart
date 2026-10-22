import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/logging/app_logger.dart';
import 'core/theme.dart';
import 'data/app_database.dart';
import 'features/auth/auth_screens.dart';
import 'features/home/home_screen.dart';
import 'features/lock/app_lock.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/voice_recognizer.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      AppLogger.error('Flutter error', d.exception, d.stack);
      if (kDebugMode) FlutterError.presentError(d);
    };
    PlatformDispatcher.instance.onError = (e, s) {
      AppLogger.error('Uncaught platform error', e, s);
      return true;
    };
    ErrorWidget.builder = (d) => const _FriendlyError();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    final db = await AppDatabase.open();
    final settings = SettingsService();
    final auth = AuthService(db);
    await settings.load();
    AppLogger.info('App started');

    runApp(ChatpodiaApp(
      db: db,
      settings: settings,
      auth: auth,
      ai: AiService(settings),
      voice: DeviceVoiceRecognizer(),
    ));
    auth.restore();
  }, (e, s) => AppLogger.error('Uncaught zone error', e, s));
}

/// Root widget. Every dependency is injected so tests and the demo recorder
/// can run the real UI against in-memory / scripted backends.
class ChatpodiaApp extends StatelessWidget {
  const ChatpodiaApp({
    super.key,
    required this.db,
    required this.settings,
    required this.auth,
    required this.ai,
    required this.voice,
    this.lockAuthenticator,
  });

  final AppDatabase db;
  final SettingsService settings;
  final AuthService auth;
  final AiClient ai;
  final VoiceRecognizer voice;
  final Future<bool> Function()? lockAuthenticator;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        Provider<AiClient>.value(value: ai),
        Provider<VoiceRecognizer>.value(value: voice),
      ],
      child: MaterialApp(
        title: 'Chatpodia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: AuthGate(lockAuthenticator: lockAuthenticator),
      ),
    );
  }
}

/// Routes between splash, onboarding/auth and the app based on session state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.lockAuthenticator});
  final Future<bool> Function()? lockAuthenticator;

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthService, AuthStatus>((a) => a.status);
    final Widget child = switch (status) {
      AuthStatus.unknown => const SplashScreen(key: ValueKey('splash')),
      AuthStatus.signedOut => const WelcomeScreen(key: ValueKey('welcome')),
      AuthStatus.signedIn => AppLockGate(
          key: const ValueKey('home'),
          authenticator: lockAuthenticator,
          child: const HomeScreen(),
        ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 1.03, end: 1.0).animate(a), child: c),
      ),
      child: child,
    );
  }
}

class _FriendlyError extends StatelessWidget {
  const _FriendlyError();
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.bgBase,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text(
          'Something went wrong here.\nPlease go back and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, decoration: TextDecoration.none),
        ),
      );
}
