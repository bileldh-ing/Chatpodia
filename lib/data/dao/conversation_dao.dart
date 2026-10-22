import 'package:sqflite/sqflite.dart';

import '../entities.dart';

class ConversationDao {
  ConversationDao(this._db);
  final Database _db;

  Future<int> insert(ConversationEntity c) => _db.insert('conversations', c.toMap()..remove('id'));

  Future<List<ConversationEntity>> forUser(int userId, {String? query}) async {
    final hasQ = query != null && query.trim().isNotEmpty;
    final r = await _db.query(
      'conversations',
      where: hasQ ? 'user_id = ? AND title LIKE ?' : 'user_id = ?',
      whereArgs: hasQ ? [userId, '%${query.trim()}%'] : [userId],
      orderBy: 'pinned DESC, updated_at DESC',
    );
    return r.map(ConversationEntity.fromMap).toList();
  }

  Future<void> touch(int id, {String? title}) => _db.update(
        'conversations',
        {'updated_at': DateTime.now().millisecondsSinceEpoch, if (title != null) 'title': title},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> setPinned(int id, bool pinned) =>
      _db.update('conversations', {'pinned': pinned ? 1 : 0}, where: 'id = ?', whereArgs: [id]);

  Future<void> rename(int id, String title) =>
      _db.update('conversations', {'title': title}, where: 'id = ?', whereArgs: [id]);

  Future<void> delete(int id) => _db.delete('conversations', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteAllForUser(int userId) => _db.delete('conversations', where: 'user_id = ?', whereArgs: [userId]);
}
