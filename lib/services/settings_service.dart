import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AiProvider { pollinations, gemini, openaiCompatible }

extension AiProviderX on AiProvider {
  String get label => switch (this) {
        AiProvider.pollinations => 'Podia Cloud (free)',
        AiProvider.gemini => 'Google Gemini',
        AiProvider.openaiCompatible => 'OpenAI-compatible',
      };
  String get subtitle => switch (this) {
        AiProvider.pollinations => 'No key needed · text, image & web generation',
        AiProvider.gemini => 'Bring your own Gemini API key',
        AiProvider.openaiCompatible => 'OpenAI, Groq, OpenRouter, Ollama…',
      };
}

/// User preferences. API keys live in the Android Keystore / iOS Keychain.
class SettingsService extends ChangeNotifier {
  SettingsService({FlutterSecureStorage? storage})
      : _s = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final FlutterSecureStorage _s;

  AiProvider provider = AiProvider.pollinations;
  String geminiKey = const String.fromEnvironment('GEMINI_API_KEY');
  String geminiModel = 'gemini-2.5-flash';
  String openaiKey = const String.fromEnvironment('OPENAI_API_KEY');
  String openaiBaseUrl = 'https://api.openai.com/v1';
  String openaiModel = 'gpt-4o-mini';
  bool speakReplies = false;
  bool haptics = true;
  bool onboardingSeen = false;
  bool appLock = false;

  Future<void> load() async {
    final all = await _s.readAll();
    provider = AiProvider.values.firstWhere((p) => p.name == all['provider'], orElse: () => provider);
    geminiKey = all['geminiKey'] ?? geminiKey;
    geminiModel = all['geminiModel'] ?? geminiModel;
    openaiKey = all['openaiKey'] ?? openaiKey;
    openaiBaseUrl = all['openaiBaseUrl'] ?? openaiBaseUrl;
    openaiModel = all['openaiModel'] ?? openaiModel;
    speakReplies = all['speakReplies'] == '1';
    haptics = all['haptics'] != '0';
    onboardingSeen = all['onboardingSeen'] == '1';
    appLock = all['appLock'] == '1';
    notifyListeners();
  }

  Future<void> _w(String k, String v) => _s.write(key: k, value: v);

  Future<void> update({
    AiProvider? provider,
    String? geminiKey,
    String? geminiModel,
    String? openaiKey,
    String? openaiBaseUrl,
    String? openaiModel,
    bool? speakReplies,
    bool? haptics,
    bool? onboardingSeen,
    bool? appLock,
  }) async {
    if (appLock != null) {
      this.appLock = appLock;
      await _w('appLock', appLock ? '1' : '0');
    }
    if (provider != null) {
      this.provider = provider;
      await _w('provider', provider.name);
    }
    if (geminiKey != null) {
      this.geminiKey = geminiKey.trim();
      await _w('geminiKey', this.geminiKey);
    }
    if (geminiModel != null) {
      this.geminiModel = geminiModel.trim();
      await _w('geminiModel', this.geminiModel);
    }
    if (openaiKey != null) {
      this.openaiKey = openaiKey.trim();
      await _w('openaiKey', this.openaiKey);
    }
    if (openaiBaseUrl != null) {
      this.openaiBaseUrl = openaiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      await _w('openaiBaseUrl', this.openaiBaseUrl);
    }
    if (openaiModel != null) {
      this.openaiModel = openaiModel.trim();
      await _w('openaiModel', this.openaiModel);
    }
    if (speakReplies != null) {
      this.speakReplies = speakReplies;
      await _w('speakReplies', speakReplies ? '1' : '0');
    }
    if (haptics != null) {
      this.haptics = haptics;
      await _w('haptics', haptics ? '1' : '0');
    }
    if (onboardingSeen != null) {
      this.onboardingSeen = onboardingSeen;
      await _w('onboardingSeen', onboardingSeen ? '1' : '0');
    }
    notifyListeners();
  }
}
