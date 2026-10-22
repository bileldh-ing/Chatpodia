import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

class ChatTurn {
  const ChatTurn(this.role, this.content, {this.images = const []});
  final String role; // user | assistant
  final String content;

  /// Attached images as `data:image/...;base64,...` URLs (vision models).
  final List<String> images;
}

/// Abstraction over the model backend so the UI can be tested and demoed
/// with a scripted client (see test/helpers/fake_ai_client.dart).
abstract class AiClient {
  Stream<String> streamChat(List<ChatTurn> history, {String? system});
  String imageUrl(String prompt, {int width, int height, int? seed});
  Future<String> titleFor(String firstMessage);
  Future<List<String>> storyboard(String idea);

  /// Whether the current backend can read attached images.
  bool get supportsVision;
}

class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum Intent { chat, image, web, motion }

/// Talks to real LLMs (streaming), and to an image model for generation.
class AiService implements AiClient {
  AiService(this._settings);
  final SettingsService _settings;
  final _client = http.Client();

  static const _pollinationsText = 'https://text.pollinations.ai/openai';
  static const _pollinationsImage = 'https://image.pollinations.ai/prompt/';

  // ------------------------------------------------------------ intent

  static Intent detectIntent(String text) {
    final q = text.toLowerCase();
    const verbs = r'(generate|create|make|draw|design|paint|render|produce|show me|give me|build|code|write)';
    if (RegExp('$verbs\\b.{0,40}\\b(video|clip|animation|motion|gif|movie|trailer)').hasMatch(q)) {
      return Intent.motion;
    }
    if (RegExp(
            '$verbs\\b.{0,40}\\b(website|web ?site|web ?page|landing page|html|web ?app|app|game|calculator|dashboard|portfolio|form|timer|clock|todo|to-do)')
        .hasMatch(q)) {
      return Intent.web;
    }
    if (RegExp('$verbs\\b.{0,40}\\b(image|picture|photo|illustration|drawing|painting|logo|icon|wallpaper|poster|art|artwork|sketch|portrait)')
            .hasMatch(q) ||
        q.startsWith('imagine ') ||
        q.startsWith('/image')) {
      return Intent.image;
    }
    return Intent.chat;
  }

  /// Strips the instruction words, leaving the subject for the image model.
  static String cleanImagePrompt(String text) {
    var p = text.replaceFirst(RegExp(r'^/image\s*', caseSensitive: false), '');
    p = p.replaceFirst(
        RegExp(
            r'^(please\s+)?(generate|create|make|draw|design|paint|render|produce|show me|give me)\s+(me\s+)?(an?\s+)?(image|picture|photo|illustration|drawing|painting|artwork|art)?\s*(of|showing|with)?\s*',
            caseSensitive: false),
        '');
    return p.trim().isEmpty ? text : p.trim();
  }

  @override
  bool get supportsVision => _settings.provider != AiProvider.pollinations;

  @override
  String imageUrl(String prompt, {int width = 1024, int height = 1024, int? seed}) {
    final s = seed ?? Random().nextInt(1 << 31);
    return '$_pollinationsImage${Uri.encodeComponent(prompt)}?width=$width&height=$height&seed=$s&nologo=true&enhance=true&model=flux';
  }

  // ------------------------------------------------------------ prompts

  static String systemPrompt({String? userName}) {
    final now = DateTime.now();
    return 'You are Podia, the friendly, concise and highly capable AI assistant inside the Chatpodia app. '
        '${userName != null ? 'The user\'s name is $userName. ' : ''}'
        'Current local date/time: ${now.toIso8601String()}. '
        'Answer in the user\'s language. Use Markdown (short paragraphs, bullet lists, bold, code blocks) when it helps. '
        'Be warm and to the point. The app itself can generate images, mini web apps and motion clips, so never say you cannot create images.';
  }

  static const webAppPrompt =
      'You are an expert front-end engineer and product designer. Build exactly what the user asks as ONE complete, '
      'self-contained HTML5 document: inline <style> and <script>, no external build steps (CDN fonts allowed). '
      'Mobile-first, responsive, polished modern UI with a dark theme, smooth micro-interactions, and fully working logic. '
      'Reply with ONLY the code inside a single ```html code block, no explanation.';

  // ------------------------------------------------------------ streaming chat

  @override
  Stream<String> streamChat(List<ChatTurn> history, {String? system}) {
    final sys = system ?? systemPrompt();
    switch (_settings.provider) {
      case AiProvider.gemini:
        if (_settings.geminiKey.isEmpty) {
          return Stream.error(AiException('Add your Gemini API key in Settings, or switch to Podia Cloud.'));
        }
        return _gemini(history, sys);
      case AiProvider.openaiCompatible:
        if (_settings.openaiKey.isEmpty) {
          return Stream.error(AiException('Add your API key in Settings, or switch to Podia Cloud.'));
        }
        return _openAiCompatible(
          url: '${_settings.openaiBaseUrl}/chat/completions',
          model: _settings.openaiModel,
          key: _settings.openaiKey,
          history: history,
          system: sys,
        );
      case AiProvider.pollinations:
        // Free tier is text-only: describe attachments instead of sending them.
        final textOnly = [
          for (final t in history)
            t.images.isEmpty ? t : ChatTurn(t.role, '${t.content}\n\n[${t.images.length} image(s) attached]')
        ];
        return _openAiCompatible(url: _pollinationsText, model: 'openai', history: textOnly, system: sys);
    }
  }

  Stream<String> _openAiCompatible({
    required String url,
    required String model,
    String? key,
    required List<ChatTurn> history,
    required String system,
  }) async* {
    final req = http.Request('POST', Uri.parse(url))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        if (key != null) 'Authorization': 'Bearer $key',
      })
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': [
          {'role': 'system', 'content': system},
          for (final t in history)
            {
              'role': t.role,
              'content': t.images.isEmpty
                  ? t.content
                  : [
                      {'type': 'text', 'text': t.content},
                      for (final img in t.images)
                        {
                          'type': 'image_url',
                          'image_url': {'url': img}
                        },
                    ],
            },
        ],
      });

    final http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw AiException('The model took too long to respond. Check your connection and retry.');
    } catch (_) {
      throw AiException('You appear to be offline. Check your connection and retry.');
    }
    if (res.statusCode >= 400) {
      final body = await res.stream.bytesToString();
      throw AiException(_friendlyHttpError(res.statusCode, body));
    }

    final ct = res.headers['content-type'] ?? '';
    if (!ct.contains('event-stream')) {
      // Provider ignored stream:true — parse a single JSON body.
      final body = await res.stream.bytesToString();
      try {
        final j = jsonDecode(body);
        final content = j['choices']?[0]?['message']?['content'] as String?;
        if (content != null) {
          yield content;
          return;
        }
      } catch (_) {}
      yield body;
      return;
    }

    await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') break;
      try {
        final j = jsonDecode(data);
        final delta = j['choices']?[0]?['delta']?['content'];
        if (delta is String && delta.isNotEmpty) yield delta;
      } catch (_) {/* keep-alive / partial */}
    }
  }

  Stream<String> _gemini(List<ChatTurn> history, String system) async* {
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${_settings.geminiModel}:streamGenerateContent?alt=sse');
    final req = http.Request('POST', uri)
      ..headers.addAll({'Content-Type': 'application/json', 'x-goog-api-key': _settings.geminiKey})
      ..body = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': system}
          ]
        },
        'contents': [
          for (final t in history)
            {
              'role': t.role == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': t.content},
                for (final img in t.images)
                  {
                    'inline_data': {
                      'mime_type': img.substring(5, img.indexOf(';')),
                      'data': img.substring(img.indexOf(',') + 1),
                    }
                  },
              ],
            }
        ],
      });

    final http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(const Duration(seconds: 45));
    } catch (_) {
      throw AiException('Could not reach Gemini. Check your connection and retry.');
    }
    if (res.statusCode >= 400) {
      throw AiException(_friendlyHttpError(res.statusCode, await res.stream.bytesToString()));
    }
    await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      try {
        final j = jsonDecode(line.substring(5).trim());
        final parts = j['candidates']?[0]?['content']?['parts'] as List?;
        if (parts == null) continue;
        for (final p in parts) {
          final t = p['text'];
          if (t is String && t.isNotEmpty) yield t;
        }
      } catch (_) {}
    }
  }

  /// One-shot completion (titles, storyboard).
  Future<String> complete(String prompt, {String? system}) async {
    final buf = StringBuffer();
    await for (final c in streamChat([ChatTurn('user', prompt)], system: system ?? 'You are a concise assistant.')) {
      buf.write(c);
    }
    return buf.toString().trim();
  }

  /// Short title for the history list.
  @override
  Future<String> titleFor(String firstMessage) async {
    final fallback = firstMessage.length > 38 ? '${firstMessage.substring(0, 38).trim()}…' : firstMessage;
    try {
      final t = await complete(
        'Give a 2-5 word title (no quotes, no punctuation at the end) for a chat that starts with: "$firstMessage"',
        system: 'Reply with the title only.',
      ).timeout(const Duration(seconds: 12));
      final clean = t.split('\n').first.replaceAll(RegExp(r'^["\x27#*\s]+|["\x27*\s.]+$'), '');
      return clean.isEmpty || clean.length > 48 ? fallback : clean;
    } catch (_) {
      return fallback;
    }
  }

  /// 4 visual frame prompts for a motion clip.
  @override
  Future<List<String>> storyboard(String idea) async {
    try {
      final raw = await complete(
        'Write 4 consecutive cinematic shot descriptions (one per line, no numbering, max 25 words each, same style, '
        'same subject, consistent lighting) for a short video about: $idea',
        system: 'Reply with exactly 4 lines.',
      ).timeout(const Duration(seconds: 25));
      final lines = raw
          .split('\n')
          .map((l) => l.replaceAll(RegExp(r'^[\s\-*\d.)]+'), '').trim())
          .where((l) => l.length > 6)
          .take(4)
          .toList();
      if (lines.length >= 3) return lines;
    } catch (_) {}
    return [
      '$idea, wide establishing shot, cinematic lighting',
      '$idea, medium shot, soft motion blur, cinematic',
      '$idea, close-up detail, shallow depth of field',
      '$idea, final wide shot, golden hour, cinematic',
    ];
  }

  static String? extractHtml(String text) {
    final m = RegExp(r'```(?:html)?\s*([\s\S]*?)(```|$)', caseSensitive: false).firstMatch(text);
    final code = (m?.group(1) ?? text).trim();
    if (code.toLowerCase().contains('<html') || code.toLowerCase().contains('<!doctype') || code.contains('<body')) {
      return code;
    }
    return null;
  }

  String _friendlyHttpError(int code, String body) {
    if (code == 401 || code == 403) return 'The API key was rejected ($code). Check it in Settings.';
    if (code == 429) return 'Rate limit reached. Wait a moment and retry.';
    if (code >= 500) return 'The AI service is having trouble ($code). Please retry.';
    try {
      final j = jsonDecode(body);
      final msg = j['error']?['message'] ?? j['message'];
      if (msg is String) return msg;
    } catch (_) {}
    return 'Request failed ($code).';
  }
}
