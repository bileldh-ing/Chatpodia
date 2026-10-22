import 'package:chatpodia/services/ai_service.dart';
import 'package:chatpodia/services/auth_service.dart';
import 'package:chatpodia/services/prebuilt_answers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Auth validation', () {
    test('email', () {
      expect(AuthService.validateEmail('alex@mail.com'), isNull);
      expect(AuthService.validateEmail('alex@'), isNotNull);
    });
    test('password policy & strength', () {
      expect(AuthService.validatePassword('short1'), isNotNull);
      expect(AuthService.validatePassword('longenough'), isNotNull);
      expect(AuthService.validatePassword('longenough1'), isNull);
      expect(AuthService.passwordStrength('Abcdef1!xyz42'), 4);
    });
  });

  group('Intent routing', () {
    test('image', () => expect(AiService.detectIntent('Generate an image of a cat'), Intent.image));
    test('web', () => expect(AiService.detectIntent('Build a tip calculator app'), Intent.web));
    test('motion', () => expect(AiService.detectIntent('Make a video of waves'), Intent.motion));
    test('chat', () => expect(AiService.detectIntent('What is the capital of Japan?'), Intent.chat));
    test('clean prompt', () => expect(AiService.cleanImagePrompt('Generate an image of a red fox'), 'a red fox'));
  });

  group('Prebuilt answers', () {
    test('greeting', () => expect(PrebuiltAnswers.match('Hi!', userName: 'Alex')!.text, contains('Alex')));
    test('time', () => expect(PrebuiltAnswers.match('what time is it?'), isNotNull));
    test('music suggestions', () {
      final a = PrebuiltAnswers.match('Recommended music')!;
      expect(a.suggestions.length, 3);
      expect(PrebuiltAnswers.match('Hi, play my favorite playlist to accompany me'), isNotNull);
    });
    test('unknown falls through to AI', () => expect(PrebuiltAnswers.match('Explain black holes'), isNull));
  });

  test('extractHtml', () {
    expect(AiService.extractHtml('```html\n<!DOCTYPE html><html></html>\n```'), startsWith('<!DOCTYPE'));
    expect(AiService.extractHtml('no code here'), isNull);
  });
}
