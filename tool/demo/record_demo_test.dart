// Demo-video recorder: drives the REAL Chatpodia UI (in-memory SQLite,
// scripted AI) and captures every frame at 30 fps as PNGs.
//
//   flutter test tool/demo/record_demo_test.dart --plain-name "scene 2"
//
// Frames land in tool/demo/out/<scene>/ and are edited into the final video
// by tool/demo/compose.py.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chatpodia/data/entities.dart';
import 'package:chatpodia/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/fake_voice.dart';
import '../../test/helpers/test_env.dart';
import 'demo_ai_client.dart';

const fps = 30;
const pixelRatio = 1.25;
final assets = '${Directory.current.path}/tool/demo/assets';

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String p) async => ByteData.view((await File(p).readAsBytes()).buffer);
  final jak = FontLoader('PlusJakartaSans');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    jak.addFont(bytes('assets/google_fonts/PlusJakartaSans-$w.ttf'));
  }
  await jak.load();
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final mat = FontLoader('MaterialIcons')
    ..addFont(bytes('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await mat.load();
  final mono = FontLoader('monospace')..addFont(bytes('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'));
  await mono.load();
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'));
  await roboto.load();
}

class Rec {
  Rec(this.tester, String scene) : dir = Directory('tool/demo/out/$scene') {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  final WidgetTester tester;
  final Directory dir;
  final key = GlobalKey();
  final touch = ValueNotifier<Offset?>(null);
  int n = 0;
  final markers = <String>[];

  Widget wrap(Widget app) => RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [
            app,
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<Offset?>(
                  valueListenable: touch,
                  builder: (_, o, __) => CustomPaint(painter: _TouchPainter(o)),
                ),
              ),
            ),
          ]),
        ),
      );

  void mark(String label) => markers.add('$n $label');

  Future<void> frame() async {
    await tester.pump(const Duration(microseconds: 1000000 ~/ fps));
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: pixelRatio);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      File('${dir.path}/f_${n.toString().padLeft(5, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    n++;
  }

  Future<void> hold(double seconds) async {
    for (var i = 0; i < (seconds * fps).round(); i++) {
      await frame();
    }
  }

  Future<void> tap(Finder f, {double after = 0.5}) async {
    final c = tester.getCenter(f.first);
    touch.value = c;
    await hold(0.2);
    await tester.tapAt(c);
    await hold(0.15);
    touch.value = null;
    await hold(after);
  }

  Future<void> type(Finder f, String text, {double cps = 22}) async {
    await tester.showKeyboard(f.first);
    final existing = tester.widget<TextField>(f.first).controller?.text ?? '';
    final perChar = (fps / cps).clamp(1, 10).round();
    for (var i = 1; i <= text.length; i++) {
      final v = existing + text.substring(0, i);
      tester.testTextInput
          .updateEditingValue(TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length)));
      if (i % perChar == 0 || i == text.length) await frame();
    }
  }

  Future<void> swipe(Finder f, Offset by, {double seconds = 0.45}) async {
    final start = tester.getCenter(f.first);
    final g = await tester.startGesture(start);
    final steps = (seconds * fps).round();
    for (var i = 0; i < steps; i++) {
      await g.moveBy(by / steps.toDouble());
      await frame();
    }
    await g.up();
  }

  void finish() => File('${dir.path}/markers.txt').writeAsStringSync(markers.join('\n'));
}

Future<(TestEnv, Rec)> boot(WidgetTester tester, String scene,
    {bool signedIn = true, bool appLock = false, Future<void> Function(TestEnv)? seed}) async {
  await tester.runAsync(_loadFonts);
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  tester.view.viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
  addTearDown(tester.view.reset);

  // Mock image picker → demo photo.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/image_picker'),
    (call) async => '$assets/plant.jpg',
  );

  late TestEnv env;
  await tester.runAsync(() async {
    env = await TestEnv.create(sameIsolate: true);
    if (signedIn) await env.auth.register(name: 'Alex Morgan', email: 'alex@chatpodia.app', password: 'Podia2026!');
    if (appLock) await env.settings.update(appLock: true);
    if (seed != null) await seed(env);
  });
  final rec = Rec(tester, scene);
  await tester.pumpWidget(rec.wrap(ChatpodiaApp(
    db: env.db,
    settings: env.settings,
    auth: env.auth,
    ai: DemoAiClient(assets),
    voice: FakeVoiceRecognizer(),
    lockAuthenticator: () async {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      return true;
    },
  )));
  return (env, rec);
}

Finder composer() => find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Type a message...');
Finder sendButton() => find.byIcon(Icons.send_outlined);

void main() {
  testWidgets('scene 1 onboarding', (tester) async {
    final (env, rec) = await boot(tester, 's1', signedIn: false);
    rec.mark('splash');
    await rec.hold(1.6);
    await tester.runAsync(env.auth.restore);
    rec.mark('welcome');
    await rec.hold(2.2);
    await rec.swipe(find.byType(PageView), const Offset(-330, 0));
    await rec.hold(1.6);
    await rec.swipe(find.byType(PageView), const Offset(-330, 0));
    await rec.hold(1.6);
    rec.mark('signup');
    await rec.tap(find.text('Get started'), after: 1.0);
    final fields = find.byType(TextField);
    await rec.tap(fields.at(0), after: 0.1);
    await rec.type(fields.at(0), 'Alex Morgan');
    await rec.tap(fields.at(1), after: 0.1);
    await rec.type(fields.at(1), 'alex@chatpodia.app');
    await rec.tap(fields.at(2), after: 0.1);
    await rec.type(fields.at(2), 'Podia2026!', cps: 10);
    await rec.hold(0.6);
    tester.testTextInput.hide();
    await rec.tap(find.text('Create account'), after: 0.2);
    rec.mark('home');
    await rec.hold(3.5);
    rec.finish();
  });

  testWidgets('scene 2 chat streaming', (tester) async {
    final (env, rec) = await boot(tester, 's2');
    await tester.runAsync(env.auth.restore);
    rec.mark('home');
    await rec.hold(2.0);
    await rec.tap(composer(), after: 0.1);
    await rec.type(composer(), "Explain quantum computing like I'm 12");
    await rec.hold(0.3);
    rec.mark('send');
    await rec.tap(sendButton(), after: 0.0);
    await rec.hold(9.5);
    rec.mark('followup');
    await rec.tap(composer(), after: 0.1);
    await rec.type(composer(), 'Show me a quantum coin flip in Python');
    tester.testTextInput.hide();
    await rec.tap(sendButton(), after: 0.0);
    await rec.hold(7.5);
    rec.finish();
  });

  testWidgets('scene 3 generate', (tester) async {
    final (env, rec) = await boot(tester, 's3');
    await tester.runAsync(env.auth.restore);
    await rec.hold(1.2);
    rec.mark('image');
    await rec.tap(find.text('Generate image'), after: 0.3);
    await rec.type(composer(), 'a cozy floating island village at golden hour');
    tester.testTextInput.hide();
    await rec.tap(sendButton(), after: 0.0);
    await rec.hold(5.0);
    rec.mark('viewer');
    await rec.tap(find.byType(Image).last, after: 2.2);
    await rec.tap(find.byIcon(Icons.close_rounded), after: 0.8);
    rec.mark('web');
    await rec.tap(composer(), after: 0.1);
    await rec.type(composer(), 'Build a pomodoro timer web app');
    tester.testTextInput.hide();
    await rec.tap(sendButton(), after: 0.0);
    await rec.hold(7.0);
    rec.mark('motion');
    await rec.tap(composer(), after: 0.1);
    await rec.type(composer(), 'Make a short video of a paper boat in a neon city');
    tester.testTextInput.hide();
    await rec.tap(sendButton(), after: 0.0);
    await rec.hold(9.0);
    rec.finish();
  });

  testWidgets('scene 6 motion', (tester) async {
    final (env, rec) = await boot(tester, 's6');
    await tester.runAsync(env.auth.restore);
    await rec.hold(0.6);
    await rec.tap(composer(), after: 0.1);
    await rec.type(composer(), 'Make a short video of a paper boat in a neon city');
    tester.testTextInput.hide();
    await rec.tap(sendButton(), after: 0.0);
    await rec.hold(9.0);
    rec.finish();
  });

  testWidgets('scene 4 voice and vision', (tester) async {
    final (env, rec) = await boot(tester, 's4');
    await tester.runAsync(env.auth.restore);
    await rec.hold(1.2);
    rec.mark('voice');
    await rec.tap(find.byIcon(Icons.graphic_eq_rounded), after: 0.0);
    await rec.hold(6.5);
    rec.mark('music');
    await rec.hold(5.5);
    rec.mark('vision');
    await rec.tap(find.byIcon(Icons.add_photo_alternate_outlined), after: 0.8);
    await rec.tap(composer(), after: 0.1);
    await rec.type(composer(), 'What plant is this and how do I care for it?');
    tester.testTextInput.hide();
    await rec.tap(sendButton(), after: 0.0);
    await rec.hold(8.0);
    rec.finish();
  });

  testWidgets('scene 5 security history settings', (tester) async {
    final (env, rec) = await boot(tester, 's5', appLock: true, seed: (env) async {
      final uid = env.auth.user!.id!;
      final now = DateTime.now();
      final titles = [
        ('Quantum computing for kids', 0),
        ('Floating island village', 0),
        ('Study playlist', 1),
        ('Pomodoro timer web app', 1),
        ('3-day trip to Rome', 3),
        ('Healthy meal ideas', 6),
      ];
      for (final (t, d) in titles) {
        final id = await env.db.conversations.insert(ConversationEntity(
          userId: uid,
          title: t,
          createdAt: now.subtract(Duration(days: d, hours: 1)),
          updatedAt: now.subtract(Duration(days: d, hours: 1)),
        ));
        await env.db.messages.insert(MessageEntity(
            conversationId: id, role: MessageRole.user, content: t, createdAt: now.subtract(Duration(days: d))));
      }
    });
    await tester.runAsync(env.auth.restore);
    rec.mark('lock');
    await rec.hold(3.2);
    rec.mark('history');
    await rec.tap(find.byIcon(Icons.notes_rounded), after: 2.0);
    final search = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Search conversations');
    await rec.tap(search, after: 0.1);
    await rec.type(search, 'quantum');
    await rec.hold(1.4);
    tester.testTextInput.hide();
    await Navigator.of(tester.element(search)).maybePop();
    await rec.hold(0.8);
    rec.mark('settings');
    await rec.tap(find.text('AM').first, after: 2.0);
    await rec.swipe(find.byType(Scrollable).first, const Offset(0, -520), seconds: 1.0);
    await rec.hold(1.5);
    await rec.swipe(find.byType(Scrollable).first, const Offset(0, -520), seconds: 1.0);
    await rec.hold(2.0);
    rec.finish();
  });
}

class _TouchPainter extends CustomPainter {
  _TouchPainter(this.o);
  final Offset? o;

  @override
  void paint(Canvas canvas, Size size) {
    if (o == null) return;
    canvas.drawCircle(
        o!,
        30,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(o!, 24, Paint()..color = Colors.white.withValues(alpha: 0.3));
    canvas.drawCircle(
        o!,
        24,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(_TouchPainter old) => old.o != o;
}
