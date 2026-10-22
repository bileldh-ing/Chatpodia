import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/app_database.dart';
import '../../data/entities.dart';
import '../../services/ai_service.dart';
import '../../services/prebuilt_answers.dart';
import '../../services/settings_service.dart';

enum ResponsePhase { idle, thinking, streaming }

/// Drives one conversation: persistence, AI streaming, generation, typing reveal.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.db,
    required this.ai,
    required this.settings,
    required this.user,
    int? conversationId,
  }) : _conversationId = conversationId;

  final AppDatabase db;
  final AiClient ai;
  final SettingsService settings;
  final UserEntity user;

  int? _conversationId;
  int? get conversationId => _conversationId;

  final List<MessageEntity> messages = [];
  String title = 'Chatpodia';

  ResponsePhase phase = ResponsePhase.idle;
  List<String> thinkingStages = const ['Thinking'];

  /// Index into [messages] of the assistant message currently being written.
  int? activeIndex;

  // Smooth typing reveal: the network fills _target, a ticker reveals it.
  String _target = '';
  String _shown = '';
  Timer? _reveal;
  StreamSubscription<String>? _sub;
  bool _disposed = false;
  final _tts = FlutterTts();

  bool get busy => phase != ResponsePhase.idle;

  Future<void> load() async {
    if (_conversationId == null) return;
    messages
      ..clear()
      ..addAll(await db.messages.forConversation(_conversationId!));
    final convs = await db.conversations.forUser(user.id!);
    title = convs.where((c) => c.id == _conversationId).map((c) => c.title).firstOrNull ?? title;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<int> _ensureConversation(String firstText) async {
    if (_conversationId != null) return _conversationId!;
    final now = DateTime.now();
    final provisional = firstText.length > 38 ? '${firstText.substring(0, 38).trim()}…' : firstText;
    _conversationId = await db.conversations.insert(
      ConversationEntity(userId: user.id!, title: provisional, createdAt: now, updatedAt: now),
    );
    title = provisional;
    // Smarter title in the background.
    unawaited(ai.titleFor(firstText).then((t) async {
      await db.conversations.rename(_conversationId!, t);
      title = t;
      _notify();
    }));
    return _conversationId!;
  }

  Future<MessageEntity> _add(MessageEntity m) async {
    final id = await db.messages.insert(m);
    final saved = m.copyWith(id: id);
    messages.add(saved);
    _notify();
    return saved;
  }

  Future<void> _replace(int index, MessageEntity m) async {
    messages[index] = m;
    if (m.id != null) await db.messages.update(m);
    _notify();
  }

  // ------------------------------------------------------------------ send

  /// Sends a message, optionally with attached image file paths.
  Future<void> send(String raw, {List<String> images = const []}) async {
    var text = raw.trim();
    if ((text.isEmpty && images.isEmpty) || busy) return;
    if (text.isEmpty) text = 'What do you see in this image?';
    if (settings.haptics) HapticFeedback.lightImpact();

    final convId = await _ensureConversation(text);
    await _add(MessageEntity(
      conversationId: convId,
      role: MessageRole.user,
      content: text,
      meta: images.isEmpty ? null : {'images': images},
      createdAt: DateTime.now(),
    ));
    await db.conversations.touch(convId);

    if (images.isNotEmpty) return _chat(convId);

    final pre = PrebuiltAnswers.match(text, userName: user.firstName);
    if (pre != null) return _answerPrebuilt(convId, pre);

    switch (AiService.detectIntent(text)) {
      case Intent.image:
        return _generateImage(convId, text);
      case Intent.web:
        return _generateWeb(convId, text);
      case Intent.motion:
        return _generateMotion(convId, text);
      case Intent.chat:
        return _chat(convId);
    }
  }

  Future<void> regenerate() async {
    if (busy || messages.isEmpty) return;
    final lastUser = messages.lastIndexWhere((m) => m.isUser);
    if (lastUser < 0) return;
    // Remove everything after the last user message.
    while (messages.length > lastUser + 1) {
      final m = messages.removeLast();
      if (m.id != null) await db.messages.delete(m.id!);
    }
    final text = messages[lastUser].content;
    final images = ((messages[lastUser].meta['images'] as List?) ?? const []).cast<String>();
    final m = messages.removeLast();
    if (m.id != null) await db.messages.delete(m.id!);
    _notify();
    await send(text, images: images);
  }

  /// Replaces the last user message with [text] and asks again.
  Future<void> editLastAndResend(String text) async {
    if (busy) return;
    final lastUser = messages.lastIndexWhere((m) => m.isUser);
    if (lastUser < 0) return;
    while (messages.length > lastUser) {
      final m = messages.removeLast();
      if (m.id != null) await db.messages.delete(m.id!);
    }
    _notify();
    await send(text);
  }

  Future<void> rename(String newTitle) async {
    if (_conversationId == null || newTitle.trim().isEmpty) return;
    title = newTitle.trim();
    await db.conversations.rename(_conversationId!, title);
    _notify();
  }

  /// Writes the conversation to a Markdown file and returns its path.
  Future<File> exportMarkdown() async {
    final b = StringBuffer('# $title\n\n_Exported from Chatpodia · ${DateTime.now().toIso8601String()}_\n\n');
    for (final m in messages) {
      b.writeln('### ${m.isUser ? 'You' : 'Podia'} · ${m.createdAt.toLocal()}');
      switch (m.kind) {
        case MessageKind.image:
          b.writeln('![image](${m.meta['url']})');
        case MessageKind.motion:
          for (final f in (m.meta['frames'] as List? ?? const [])) {
            b.writeln('![frame]($f)');
          }
        case MessageKind.web:
          b.writeln('```html\n${m.meta['html'] ?? ''}\n```');
        default:
          b.writeln(m.content);
      }
      b.writeln();
    }
    final dir = await getTemporaryDirectory();
    final safe = title.replaceAll(RegExp(r'[^\w\- ]'), '').trim().replaceAll(' ', '_');
    final f = File('${dir.path}/${safe.isEmpty ? 'chat' : safe}.md');
    return f.writeAsString(b.toString());
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _finishStreaming(interrupted: true);
  }

  // ------------------------------------------------------------------ flows

  Future<MessageEntity> _placeholder(int convId,
      {MessageKind kind = MessageKind.text, Map<String, dynamic>? meta}) async {
    final m = await _add(MessageEntity(
      conversationId: convId,
      role: MessageRole.assistant,
      kind: kind,
      content: '',
      meta: meta,
      createdAt: DateTime.now(),
    ));
    activeIndex = messages.length - 1;
    return m;
  }

  Future<void> _answerPrebuilt(int convId, PrebuiltAnswer a) async {
    thinkingStages = const ['Thinking'];
    phase = ResponsePhase.thinking;
    await _placeholder(convId,
        kind: a.suggestions.isEmpty ? MessageKind.text : MessageKind.suggestions,
        meta: a.suggestions.isEmpty
            ? null
            : {
                'title': a.suggestionsTitle ?? 'Quick reply suggestions',
                'items': a.suggestions.map((s) => s.toJson()).toList(),
              });
    _notify();
    await Future.delayed(const Duration(milliseconds: 650));
    _onDone = null;
    _beginStreaming();
    _target = a.text;
    _sub = null;
    _networkDone = true;
  }

  Future<void> _chat(int convId) async {
    thinkingStages = const ['Understanding your request', 'Thinking', 'Composing answer'];
    phase = ResponsePhase.thinking;
    await _placeholder(convId);
    final source = messages
        .where((m) => m.content.isNotEmpty && (m.kind == MessageKind.text || m.kind == MessageKind.suggestions))
        .toList();
    final lastUserMsg = source.lastWhere((m) => m.isUser, orElse: () => source.last);
    final history = <ChatTurn>[];
    for (final m in source) {
      var images = const <String>[];
      // Only the newest user turn carries pixels — keeps requests small.
      if (identical(m, lastUserMsg)) images = await _encodeImages(m);
      history.add(ChatTurn(m.isUser ? 'user' : 'assistant', m.content, images: images));
    }
    if (lastUserMsg.meta['images'] != null && !ai.supportsVision) {
      thinkingStages = const ['Reading your attachment', 'Thinking', 'Composing answer'];
    }
    // keep context bounded
    final ctx = history.length > 24 ? history.sublist(history.length - 24) : history;
    _stream(ai.streamChat(ctx, system: AiService.systemPrompt(userName: user.firstName)));
  }

  Future<void> _generateWeb(int convId, String text) async {
    thinkingStages = const ['Planning the layout', 'Designing components', 'Writing the code'];
    phase = ResponsePhase.thinking;
    await _placeholder(convId, kind: MessageKind.web, meta: {'prompt': text, 'status': 'building'});
    _stream(ai.streamChat([ChatTurn('user', text)], system: AiService.webAppPrompt), onDone: (full) async {
      final i = activeIndex ?? messages.length - 1;
      final html = AiService.extractHtml(full);
      final m = messages[i];
      await _replace(
        i,
        html == null
            ? m.copyWith(kind: MessageKind.text, content: full)
            : m.copyWith(content: 'Your app is ready.', meta: {'prompt': text, 'status': 'ready', 'html': html}),
      );
    });
  }

  Future<void> _generateImage(int convId, String text) async {
    final prompt = AiService.cleanImagePrompt(text);
    final url = ai.imageUrl(prompt);
    phase = ResponsePhase.idle;
    await _placeholder(convId, kind: MessageKind.image, meta: {'prompt': prompt, 'url': url});
    final i = messages.length - 1;
    await _replace(i, messages[i].copyWith(content: 'Here\'s your image: *$prompt*'));
    activeIndex = null;
    _notify();
  }

  Future<void> _generateMotion(int convId, String text) async {
    thinkingStages = const ['Writing the storyboard', 'Framing the shots', 'Rendering frames'];
    phase = ResponsePhase.thinking;
    await _placeholder(convId, kind: MessageKind.motion, meta: {'prompt': text, 'status': 'storyboard'});
    final idea = AiService.cleanImagePrompt(
        text.replaceAll(RegExp(r'\b(video|clip|animation|motion|gif|movie|trailer)\b', caseSensitive: false), 'scene'));
    final shots = await ai.storyboard(idea);
    final seed = DateTime.now().millisecondsSinceEpoch % 100000;
    final frames = [for (final s in shots) ai.imageUrl(s, width: 768, height: 1024, seed: seed)];
    final i = messages.length - 1;
    phase = ResponsePhase.idle;
    activeIndex = null;
    await _replace(
        i,
        messages[i]
            .copyWith(content: idea, meta: {'prompt': text, 'status': 'ready', 'frames': frames, 'shots': shots}));
  }

  Future<List<String>> _encodeImages(MessageEntity m) async {
    final paths = ((m.meta['images'] as List?) ?? const []).cast<String>();
    final out = <String>[];
    for (final p in paths) {
      try {
        final bytes = await File(p).readAsBytes();
        final ext = p.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        out.add('data:image/$ext;base64,${base64Encode(bytes)}');
      } catch (_) {/* file removed */}
    }
    return out;
  }

  // ------------------------------------------------------------------ streaming core

  bool _networkDone = false;
  FutureOr<void> Function(String full)? _onDone;

  void _beginStreaming() {
    phase = ResponsePhase.streaming;
    _target = '';
    _shown = '';
    _networkDone = false;
    _reveal?.cancel();
    _reveal = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    _notify();
  }

  void _stream(Stream<String> s, {FutureOr<void> Function(String full)? onDone}) {
    _onDone = onDone;
    var started = false;
    _sub = s.listen(
      (chunk) {
        if (!started) {
          started = true;
          _beginStreaming();
        }
        _target += chunk;
      },
      onError: (Object e) async {
        _reveal?.cancel();
        final i = activeIndex ?? messages.length - 1;
        phase = ResponsePhase.idle;
        activeIndex = null;
        await _replace(i, messages[i].copyWith(kind: MessageKind.error, content: e.toString()));
      },
      onDone: () {
        if (!started) _beginStreaming();
        _networkDone = true;
      },
      cancelOnError: true,
    );
  }

  void _tick() {
    if (activeIndex == null) return;
    final remaining = _target.length - _shown.length;
    if (remaining > 0) {
      // Reveal faster when far behind — feels smooth like a pro assistant.
      final step = remaining > 400
          ? 24
          : remaining > 120
              ? 8
              : remaining > 30
                  ? 3
                  : 1;
      _shown = _target.substring(0, _shown.length + step);
      final i = activeIndex!;
      messages[i] = messages[i].copyWith(content: _shown);
      _notify();
    } else if (_networkDone) {
      _finishStreaming();
    }
  }

  Future<void> _finishStreaming({bool interrupted = false}) async {
    _reveal?.cancel();
    final i = activeIndex;
    if (i == null) {
      phase = ResponsePhase.idle;
      _notify();
      return;
    }
    final full = interrupted ? _shown : _target;
    activeIndex = null;
    phase = ResponsePhase.idle;
    final m = messages[i].copyWith(content: full.isEmpty && interrupted ? '_Stopped._' : full);
    await _replace(i, m);
    final cb = _onDone;
    _onDone = null;
    if (cb != null && !interrupted) await cb(full);
    if (_conversationId != null) await db.conversations.touch(_conversationId!);
    if (!interrupted && settings.speakReplies && m.kind == MessageKind.text) speak(full);
    if (settings.haptics) HapticFeedback.selectionClick();
  }

  // ------------------------------------------------------------------ misc

  Future<void> speak(String text) async {
    final plain = text.replaceAll(RegExp(r'[*_`#>\[\]()]'), '');
    await _tts.stop();
    await _tts.setSpeechRate(0.5);
    await _tts.speak(plain);
  }

  Future<void> deleteMessage(MessageEntity m) async {
    messages.remove(m);
    if (m.id != null) await db.messages.delete(m.id!);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _reveal?.cancel();
    _tts.stop();
    super.dispose();
  }
}
