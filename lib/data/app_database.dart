import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'dao/conversation_dao.dart';
import 'dao/message_dao.dart';
import 'dao/session_dao.dart';
import 'dao/user_dao.dart';

/// Room-style database: one SQLite file, a versioned schema with migrations,
/// foreign keys with cascades, indices, and one DAO per aggregate.
class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;

  static const _name = 'chatpodia.db';
  static const _version = 2;

  late final UserDao users = UserDao(_db);
  late final SessionDao sessions = SessionDao(_db);
  late final ConversationDao conversations = ConversationDao(_db);
  late final MessageDao messages = MessageDao(_db);

  Future<void> close() => _db.close();

  /// [factory] / [path] are injectable so tests can use an in-memory FFI database.
  static Future<AppDatabase> open({DatabaseFactory? factory, String? path}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), _name);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, v) async {
          await _createV1(db);
          await _migrateV2(db);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await _migrateV2(db);
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createV1(Database db) async {
    final b = db.batch();
    b.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT,
        salt TEXT,
        provider TEXT NOT NULL DEFAULT 'password',
        avatar_url TEXT,
        created_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE sessions(
        token TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE conversations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        kind TEXT NOT NULL,
        content TEXT NOT NULL,
        meta TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL
      )''');
    b.execute('CREATE INDEX idx_conv_user ON conversations(user_id, updated_at DESC)');
    b.execute('CREATE INDEX idx_msg_conv ON messages(conversation_id, created_at)');
    await b.commit(noResult: true);
  }

  /// v2: brute-force protection columns.
  static Future<void> _migrateV2(Database db) async {
    await db.execute('ALTER TABLE users ADD COLUMN failed_attempts INTEGER NOT NULL DEFAULT 0');
    await db.execute('ALTER TABLE users ADD COLUMN locked_until INTEGER');
  }
}
