import 'package:chatpodia/data/app_database.dart';
import 'package:chatpodia/services/auth_service.dart';
import 'package:chatpodia/services/settings_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real SQLite (in-memory, via FFI) + mocked keystore.
class TestEnv {
  TestEnv._(this.db, this.auth, this.settings);
  final AppDatabase db;
  final AuthService auth;
  final SettingsService settings;

  static Future<TestEnv> create({bool sameIsolate = false}) async {
    sqfliteFfiInit();
    FlutterSecureStorage.setMockInitialValues({});
    final db = await AppDatabase.open(
      factory: sameIsolate ? databaseFactoryFfiNoIsolate : databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final settings = SettingsService();
    await settings.load();
    // Low iteration count keeps tests fast; production uses 120k.
    final auth = AuthService(db, iterations: 1000);
    return TestEnv._(db, auth, settings);
  }

  Future<void> dispose() => db.close();
}
