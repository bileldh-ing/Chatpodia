import 'package:sqflite/sqflite.dart';

import '../entities.dart';

class UserDao {
  UserDao(this._db);
  final Database _db;

  Future<int> insert(UserEntity u) =>
      _db.insert('users', u.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.abort);

  Future<UserEntity?> findByEmail(String email) async {
    final r = await _db.query('users', where: 'email = ?', whereArgs: [email.trim().toLowerCase()], limit: 1);
    return r.isEmpty ? null : UserEntity.fromMap(r.first);
  }

  Future<UserEntity?> findById(int id) async {
    final r = await _db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : UserEntity.fromMap(r.first);
  }

  Future<void> setLockState(int id, int attempts, DateTime? lockedUntil) => _db.update(
        'users',
        {'failed_attempts': attempts, 'locked_until': lockedUntil?.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> updateProfile(int id, {String? name, String? passwordHash, String? salt}) => _db.update(
        'users',
        {
          if (name != null) 'name': name,
          if (passwordHash != null) 'password_hash': passwordHash,
          if (salt != null) 'salt': salt,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> delete(int id) => _db.delete('users', where: 'id = ?', whereArgs: [id]);
}
