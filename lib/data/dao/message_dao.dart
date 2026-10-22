import 'package:sqflite/sqflite.dart';

import '../entities.dart';

class MessageDao {
  MessageDao(this._db);
  final Database _db;

  Future<int> insert(MessageEntity m) => _db.insert('messages', m.toMap()..remove('id'));

  Future<void> update(MessageEntity m) => _db.update('messages', m.toMap(), where: 'id = ?', whereArgs: [m.id]);

  Future<List<MessageEntity>> forConversation(int conversationId) async {
    final r = await _db.query('messages',
        where: 'conversation_id = ?', whereArgs: [conversationId], orderBy: 'created_at ASC, id ASC');
    return r.map(MessageEntity.fromMap).toList();
  }

  Future<void> delete(int id) => _db.delete('messages', where: 'id = ?', whereArgs: [id]);
}
