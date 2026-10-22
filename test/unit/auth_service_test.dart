import 'package:chatpodia/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestEnv env;

  setUp(() async => env = await TestEnv.create());
  tearDown(() => env.dispose());

  test('register creates a user and signs in', () async {
    await env.auth.register(name: 'Alex Morgan', email: 'Alex@Mail.com', password: 'secret123');
    expect(env.auth.isSignedIn, isTrue);
    expect(env.auth.user!.email, 'alex@mail.com');
    expect(env.auth.user!.firstName, 'Alex');
    expect(env.auth.user!.passwordHash, isNot(contains('secret123')));
  });

  test('duplicate email is rejected', () async {
    await env.auth.register(name: 'Alex', email: 'a@b.co', password: 'secret123');
    await env.auth.signOut();
    expect(
      () => env.auth.register(name: 'Other', email: 'A@B.co', password: 'secret123'),
      throwsA(isA<AuthException>()),
    );
  });

  test('sign in with correct and wrong password', () async {
    await env.auth.register(name: 'Alex', email: 'a@b.co', password: 'secret123');
    await env.auth.signOut();
    expect(env.auth.isSignedIn, isFalse);
    await expectLater(env.auth.signIn(email: 'a@b.co', password: 'nope12345'), throwsA(isA<AuthException>()));
    await env.auth.signIn(email: 'a@b.co', password: 'secret123');
    expect(env.auth.isSignedIn, isTrue);
  });

  test('locks the account after 5 failed attempts', () async {
    await env.auth.register(name: 'Alex', email: 'a@b.co', password: 'secret123');
    await env.auth.signOut();
    for (var i = 0; i < 5; i++) {
      await expectLater(env.auth.signIn(email: 'a@b.co', password: 'wrong1234'), throwsA(isA<AuthException>()));
    }
    await expectLater(
      env.auth.signIn(email: 'a@b.co', password: 'secret123'),
      throwsA(predicate((e) => e is AuthException && e.message.contains('Too many attempts'))),
    );
  });

  test('session survives a restart (restore)', () async {
    await env.auth.register(name: 'Alex', email: 'a@b.co', password: 'secret123');
    final again = AuthService(env.db, iterations: 1000);
    await again.restore();
    expect(again.status, AuthStatus.signedIn);
    expect(again.user!.email, 'a@b.co');
  });

  test('change password and delete account', () async {
    await env.auth.register(name: 'Alex', email: 'a@b.co', password: 'secret123');
    await env.auth.changePassword('secret123', 'newpass456');
    await env.auth.signOut();
    await env.auth.signIn(email: 'a@b.co', password: 'newpass456');
    await env.auth.deleteAccount();
    expect(env.auth.isSignedIn, isFalse);
    expect(await env.db.users.findByEmail('a@b.co'), isNull);
  });
}
