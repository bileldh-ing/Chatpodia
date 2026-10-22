import 'package:sqflite/sqflite.dart';

import '../entities.dart';

class SessionDao {
  SessionDao(this._db);
  final Database _db;

  Future<void> insert(SessionEntity s) =>
      _db.insert('sessions', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<SessionEntity?> find(String token) async {
    final r = await _db.query('sessions', where: 'token = ?', whereArgs: [token], limit: 1);
    return r.isEmpty ? null : SessionEntity.fromMap(r.first);
  }

  Future<void> delete(String token) => _db.delete('sessions', where: 'token = ?', whereArgs: [token]);

  Future<void> purgeExpired() =>
      _db.delete('sessions', where: 'expires_at < ?', whereArgs: [DateTime.now().millisecondsSinceEpoch]);
}
