import 'dart:async';

import 'package:chatpodia/services/ai_service.dart';

/// Scripted, deterministic AI backend for tests and the demo recorder.
class FakeAiClient implements AiClient {
  FakeAiClient({
    this.reply = 'Here is a **helpful** answer.',
    this.chunkDelay = const Duration(milliseconds: 30),
    this.imagePath,
    this.framePaths = const [],
    this.html = '```html\n<!DOCTYPE html><html><body><h1>Hello</h1></body></html>\n```',
    this.vision = true,
  });

  String reply;
  final Duration chunkDelay;
  final String? imagePath;
  final List<String> framePaths;
  final String html;
  final bool vision;
  final List<List<ChatTurn>> calls = [];

  @override
  bool get supportsVision => vision;

  @override
  Stream<String> streamChat(List<ChatTurn> history, {String? system}) async* {
    calls.add(history);
    final text = (system ?? '').contains('front-end engineer') ? html : reply;
    final words = RegExp(r'\S+\s*').allMatches(text).map((m) => m.group(0)!).toList();
    for (final w in words) {
      await Future<void>.delayed(chunkDelay);
      yield w;
    }
  }

  @override
  String imageUrl(String prompt, {int width = 1024, int height = 1024, int? seed}) =>
      imagePath ?? 'https://example.com/$prompt.png';

  @override
  Future<String> titleFor(String firstMessage) async =>
      firstMessage.length > 24 ? firstMessage.substring(0, 24) : firstMessage;

  @override
  Future<List<String>> storyboard(String idea) async => ['$idea wide', '$idea close', '$idea detail', '$idea final'];
}

class ThrowingAiClient extends FakeAiClient {
  @override
  Stream<String> streamChat(List<ChatTurn> history, {String? system}) =>
      Stream.error(AiException('You appear to be offline. Check your connection and retry.'));
}
