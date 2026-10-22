import 'package:chatpodia/data/entities.dart';
import 'package:chatpodia/features/chat/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ai_client.dart';
import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create();
    await env.auth.register(name: 'Alex', email: 'a@b.co', password: 'secret123');
  });
  tearDown(() => env.dispose());

  ChatController make(FakeAiClient ai) =>
      ChatController(db: env.db, ai: ai, settings: env.settings, user: env.auth.user!);

  Future<void> settle(ChatController c) async {
    for (var i = 0; i < 400 && c.busy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('streams an AI answer and persists both messages', () async {
    final c = make(FakeAiClient(reply: 'Tokyo is the capital of Japan.', chunkDelay: Duration.zero));
    await c.send('What is the capital of Japan?');
    await settle(c);
    expect(c.messages.length, 2);
    expect(c.messages.last.content, 'Tokyo is the capital of Japan.');
    final stored = await env.db.messages.forConversation(c.conversationId!);
    expect(stored.map((m) => m.role), [MessageRole.user, MessageRole.assistant]);
  });

  test('prebuilt answers do not call the model', () async {
    final ai = FakeAiClient(chunkDelay: Duration.zero);
    final c = make(ai);
    await c.send('what time is it?');
    await settle(c);
    expect(ai.calls, isEmpty);
    expect(c.messages.last.content, contains('right now'));
  });

  test('image intent creates an image message', () async {
    final c = make(FakeAiClient(imagePath: '/tmp/x.png'));
    await c.send('Generate an image of a neon forest');
    await settle(c);
    expect(c.messages.last.kind, MessageKind.image);
    expect(c.messages.last.meta['prompt'], 'a neon forest');
  });

  test('web intent extracts html', () async {
    final c = make(FakeAiClient(chunkDelay: Duration.zero));
    await c.send('Build a todo list app');
    await settle(c);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.messages.last.kind, MessageKind.web);
    expect(c.messages.last.meta['html'], contains('<h1>Hello</h1>'));
  });

  test('network failure becomes a retryable error bubble', () async {
    final c = make(ThrowingAiClient());
    await c.send('Explain black holes');
    await settle(c);
    expect(c.messages.last.kind, MessageKind.error);
  });

  test('edit & resend replaces the last exchange', () async {
    final c = make(FakeAiClient(reply: 'One.', chunkDelay: Duration.zero));
    await c.send('Say one');
    await settle(c);
    await c.editLastAndResend('Say two');
    await settle(c);
    expect(c.messages.where((m) => m.isUser).map((m) => m.content), ['Say two']);
  });
}
