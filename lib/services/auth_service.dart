import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/app_database.dart';
import '../data/entities.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum AuthStatus { unknown, signedOut, signedIn }

/// Real, offline-first authentication:
///  • accounts stored in SQLite (users table)
///  • PBKDF2-HMAC-SHA256 (120k iterations, 16-byte salt) computed off the UI isolate
///  • opaque session tokens (sessions table) mirrored in the Keystore/Keychain
///  • lockout after 5 failed attempts
///  • optional Google Sign-In (OAuth) that links to a local account
class AuthService extends ChangeNotifier {
  AuthService(this._db, {int iterations = 120000, FlutterSecureStorage? storage, GoogleSignIn? google})
      : _iterations = iterations,
        _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true)),
        _googleOverride = google;

  final AppDatabase _db;
  final FlutterSecureStorage _storage;
  final GoogleSignIn? _googleOverride;
  late final GoogleSignIn _google = _googleOverride ?? GoogleSignIn(scopes: const ['email', 'profile']);
  final int _iterations;

  static const _tokenKey = 'chatpodia.session';
  static const _sessionTtl = Duration(days: 30);
  static const _maxAttempts = 5;
  static const _lockDuration = Duration(minutes: 2);

  AuthStatus _status = AuthStatus.unknown;
  UserEntity? _user;
  String? _token;

  AuthStatus get status => _status;
  UserEntity? get user => _user;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  // ---------------------------------------------------------------- session

  Future<void> restore() async {
    try {
      await _db.sessions.purgeExpired();
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        final s = await _db.sessions.find(token);
        if (s != null && !s.isExpired) {
          _user = await _db.users.findById(s.userId);
          _token = token;
        }
      }
    } catch (_) {
      // corrupted keystore etc. → treat as signed out
    }
    _status = _user != null ? AuthStatus.signedIn : AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _startSession(UserEntity u) async {
    final token = _randomHex(32);
    final now = DateTime.now();
    await _db.sessions
        .insert(SessionEntity(token: token, userId: u.id!, createdAt: now, expiresAt: now.add(_sessionTtl)));
    await _storage.write(key: _tokenKey, value: token);
    _token = token;
    _user = u;
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  // ---------------------------------------------------------------- email/password

  Future<void> register({required String name, required String email, required String password}) async {
    final e = email.trim().toLowerCase();
    final n = name.trim();
    final nameErr = validateName(n);
    final emailErr = validateEmail(e);
    final pwErr = validatePassword(password);
    if (nameErr != null) throw AuthException(nameErr);
    if (emailErr != null) throw AuthException(emailErr);
    if (pwErr != null) throw AuthException(pwErr);
    if (await _db.users.findByEmail(e) != null) {
      throw AuthException('An account with this email already exists.');
    }
    final salt = _randomBytes(16);
    final hash = await compute(_pbkdf2Isolate, _HashJob(password, salt, _iterations));
    final u = UserEntity(
      name: n,
      email: e,
      passwordHash: hash,
      salt: base64Encode(salt),
      createdAt: DateTime.now(),
    );
    final id = await _db.users.insert(u);
    await _startSession((await _db.users.findById(id))!);
  }

  Future<void> signIn({required String email, required String password}) async {
    final e = email.trim().toLowerCase();
    final u = await _db.users.findByEmail(e);
    // Constant-ish timing: still hash when user missing.
    if (u == null || u.passwordHash == null || u.salt == null) {
      await compute(_pbkdf2Isolate, _HashJob(password, _randomBytes(16), _iterations));
      if (u != null && u.provider == 'google') {
        throw AuthException('This account uses Google. Tap "Continue with Google".');
      }
      throw AuthException('Incorrect email or password.');
    }
    if (u.lockedUntil != null && DateTime.now().isBefore(u.lockedUntil!)) {
      final secs = u.lockedUntil!.difference(DateTime.now()).inSeconds + 1;
      throw AuthException('Too many attempts. Try again in ${secs}s.');
    }
    final hash = await compute(_pbkdf2Isolate, _HashJob(password, base64Decode(u.salt!), _iterations));
    if (!_constantTimeEquals(hash, u.passwordHash!)) {
      final attempts = u.failedAttempts + 1;
      final lock = attempts >= _maxAttempts ? DateTime.now().add(_lockDuration) : null;
      await _db.users.setLockState(u.id!, lock != null ? 0 : attempts, lock);
      throw AuthException(lock != null
          ? 'Too many attempts. Account locked for ${_lockDuration.inMinutes} minutes.'
          : 'Incorrect email or password. ${_maxAttempts - attempts} attempts left.');
    }
    await _db.users.setLockState(u.id!, 0, null);
    await _startSession(u);
  }

  Future<void> changePassword(String current, String next) async {
    final u = _user;
    if (u == null || u.salt == null) throw AuthException('Not available for this account.');
    final h = await compute(_pbkdf2Isolate, _HashJob(current, base64Decode(u.salt!), _iterations));
    if (!_constantTimeEquals(h, u.passwordHash!)) throw AuthException('Current password is incorrect.');
    final err = validatePassword(next);
    if (err != null) throw AuthException(err);
    final salt = _randomBytes(16);
    final nh = await compute(_pbkdf2Isolate, _HashJob(next, salt, _iterations));
    await _db.users.updateProfile(u.id!, passwordHash: nh, salt: base64Encode(salt));
    _user = await _db.users.findById(u.id!);
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final u = _user;
    if (u == null) return;
    final err = validateName(name.trim());
    if (err != null) throw AuthException(err);
    await _db.users.updateProfile(u.id!, name: name.trim());
    _user = await _db.users.findById(u.id!);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Google OAuth

  Future<void> signInWithGoogle() async {
    GoogleSignInAccount? acc;
    try {
      acc = await _google.signIn();
    } catch (e) {
      throw AuthException('Google Sign-In is not configured for this build yet. Add your OAuth client (see README).');
    }
    if (acc == null) throw AuthException('Google sign-in was cancelled.');
    final email = acc.email.toLowerCase();
    var u = await _db.users.findByEmail(email);
    if (u == null) {
      final id = await _db.users.insert(UserEntity(
        name: acc.displayName ?? email.split('@').first,
        email: email,
        provider: 'google',
        avatarUrl: acc.photoUrl,
        createdAt: DateTime.now(),
      ));
      u = await _db.users.findById(id);
    }
    await _startSession(u!);
  }

  // ---------------------------------------------------------------- sign out / delete

  Future<void> signOut() async {
    if (_token != null) await _db.sessions.delete(_token!);
    await _storage.delete(key: _tokenKey);
    if (_user?.provider == 'google') {
      try {
        await _google.signOut();
      } catch (_) {}
    }
    _token = null;
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final u = _user;
    if (u == null) return;
    await _db.users.delete(u.id!); // cascades sessions, conversations, messages
    await signOut();
  }

  // ---------------------------------------------------------------- validation

  static String? validateName(String v) => v.trim().length < 2 ? 'Please enter your name.' : null;

  static String? validateEmail(String v) {
    final ok = RegExp(r"^[\w.!#$%&'*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$").hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address.';
  }

  static String? validatePassword(String v) {
    if (v.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Use at least one letter and one number.';
    }
    return null;
  }

  /// 0..4 strength score for the meter.
  static int passwordStrength(String v) {
    var s = 0;
    if (v.length >= 8) s++;
    if (v.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) s++;
    if (RegExp(r'\d').hasMatch(v) && RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s++;
    return s;
  }

  // ---------------------------------------------------------------- crypto helpers

  static final _rng = Random.secure();
  static Uint8List _randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));
  static String _randomHex(int n) => _randomBytes(n).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }
}

class _HashJob {
  _HashJob(this.password, this.salt, this.iterations);
  final String password;
  final List<int> salt;
  final int iterations;
}

/// PBKDF2-HMAC-SHA256, 32-byte derived key, base64.
String _pbkdf2Isolate(_HashJob job) {
  final hmac = Hmac(sha256, utf8.encode(job.password));
  final block = Uint8List.fromList([...job.salt, 0, 0, 0, 1]);
  var u = hmac.convert(block).bytes;
  final out = Uint8List.fromList(u);
  for (var i = 1; i < job.iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return base64Encode(out);
}
