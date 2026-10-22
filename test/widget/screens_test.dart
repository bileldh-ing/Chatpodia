import 'package:chatpodia/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ai_client.dart';
import '../helpers/fake_voice.dart';
import '../helpers/test_env.dart';

void main() {
  late TestEnv env;

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChatpodiaApp(
      db: env.db,
      settings: env.settings,
      auth: env.auth,
      ai: FakeAiClient(chunkDelay: Duration.zero),
      voice: FakeVoiceRecognizer(),
    ));
  }

  testWidgets('signed-out users land on the welcome screen', (tester) async {
    await tester.runAsync(() async {
      env = await TestEnv.create();
      await env.auth.restore();
    });
    await boot(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Meet Podia'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    await tester.runAsync(env.dispose);
  });

  testWidgets('signed-in users see the personalised home', (tester) async {
    await tester.runAsync(() async {
      env = await TestEnv.create();
      await env.auth.register(name: 'Alex Morgan', email: 'a@b.co', password: 'secret123');
    });
    await boot(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Alex!'), findsOneWidget);
    expect(find.text('Generate image'), findsOneWidget);
    expect(find.text('Popular topics'), findsOneWidget);
    expect(find.text('Type a message...'), findsOneWidget);
    await tester.runAsync(env.dispose);
  });

  testWidgets('login validates the email field', (tester) async {
    await tester.runAsync(() async {
      env = await TestEnv.create();
      await env.auth.restore();
    });
    await boot(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('I already have an account'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.runAsync(env.dispose);
  });
}
