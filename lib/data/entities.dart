import 'dart:convert';

/// Room-style entities. Each maps 1:1 to a SQLite table.

class UserEntity {
  UserEntity({
    this.id,
    required this.name,
    required this.email,
    this.passwordHash,
    this.salt,
    this.provider = 'password',
    this.avatarUrl,
    required this.createdAt,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final int? id;
  final String name;
  final String email;
  final String? passwordHash;
  final String? salt;
  final String provider; // password | google
  final String? avatarUrl;
  final DateTime createdAt;
  final int failedAttempts;
  final DateTime? lockedUntil;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'password_hash': passwordHash,
        'salt': salt,
        'provider': provider,
        'avatar_url': avatarUrl,
        'created_at': createdAt.millisecondsSinceEpoch,
        'failed_attempts': failedAttempts,
        'locked_until': lockedUntil?.millisecondsSinceEpoch,
      };

  factory UserEntity.fromMap(Map<String, Object?> m) => UserEntity(
        id: m['id'] as int?,
        name: m['name'] as String,
        email: m['email'] as String,
        passwordHash: m['password_hash'] as String?,
        salt: m['salt'] as String?,
        provider: (m['provider'] as String?) ?? 'password',
        avatarUrl: m['avatar_url'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        failedAttempts: (m['failed_attempts'] as int?) ?? 0,
        lockedUntil: m['locked_until'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['locked_until'] as int),
      );
}

class SessionEntity {
  SessionEntity({required this.token, required this.userId, required this.createdAt, required this.expiresAt});
  final String token;
  final int userId;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, Object?> toMap() => {
        'token': token,
        'user_id': userId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'expires_at': expiresAt.millisecondsSinceEpoch,
      };

  factory SessionEntity.fromMap(Map<String, Object?> m) => SessionEntity(
        token: m['token'] as String,
        userId: m['user_id'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(m['expires_at'] as int),
      );
}

class ConversationEntity {
  ConversationEntity({
    this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
  });
  final int? id;
  final int userId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'pinned': pinned ? 1 : 0,
      };

  factory ConversationEntity.fromMap(Map<String, Object?> m) => ConversationEntity(
        id: m['id'] as int?,
        userId: m['user_id'] as int,
        title: m['title'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
        pinned: (m['pinned'] as int? ?? 0) == 1,
      );
}

enum MessageRole { user, assistant }

enum MessageKind { text, image, web, motion, suggestions, error }

class MessageEntity {
  MessageEntity({
    this.id,
    required this.conversationId,
    required this.role,
    this.kind = MessageKind.text,
    required this.content,
    Map<String, dynamic>? meta,
    required this.createdAt,
  }) : meta = meta ?? const {};

  final int? id;
  final int conversationId;
  final MessageRole role;
  final MessageKind kind;
  final String content;
  final Map<String, dynamic> meta;
  final DateTime createdAt;

  bool get isUser => role == MessageRole.user;

  MessageEntity copyWith({int? id, String? content, MessageKind? kind, Map<String, dynamic>? meta}) => MessageEntity(
        id: id ?? this.id,
        conversationId: conversationId,
        role: role,
        kind: kind ?? this.kind,
        content: content ?? this.content,
        meta: meta ?? this.meta,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'role': role.name,
        'kind': kind.name,
        'content': content,
        'meta': jsonEncode(meta),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory MessageEntity.fromMap(Map<String, Object?> m) => MessageEntity(
        id: m['id'] as int?,
        conversationId: m['conversation_id'] as int,
        role: MessageRole.values.byName(m['role'] as String),
        kind: MessageKind.values.byName(m['kind'] as String),
        content: m['content'] as String,
        meta: (jsonDecode((m['meta'] as String?) ?? '{}') as Map).cast<String, dynamic>(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
