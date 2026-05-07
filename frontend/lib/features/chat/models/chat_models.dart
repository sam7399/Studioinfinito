class ChatUser {
  final int id;
  final String name;
  final String? email;
  final String? role;

  ChatUser({required this.id, required this.name, this.email, this.role});

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
        id: j['id'] as int,
        name: (j['name'] as String?) ?? 'User',
        email: j['email'] as String?,
        role: j['role'] as String?,
      );
}

class ChatMember {
  final int id;
  final int roomId;
  final int userId;
  final ChatUser? user;
  final DateTime? lastReadAt;

  ChatMember({
    required this.id,
    required this.roomId,
    required this.userId,
    this.user,
    this.lastReadAt,
  });

  factory ChatMember.fromJson(Map<String, dynamic> j) => ChatMember(
        id: j['id'] as int,
        roomId: j['room_id'] as int,
        userId: j['user_id'] as int,
        user: j['user'] != null ? ChatUser.fromJson(Map<String, dynamic>.from(j['user'])) : null,
        lastReadAt: j['last_read_at'] != null ? DateTime.tryParse(j['last_read_at'].toString()) : null,
      );
}

class ChatMessage {
  final int id;
  final int roomId;
  final int senderUserId;
  final String body;
  final String messageType;
  final int? replyToId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final ChatUser? sender;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderUserId,
    required this.body,
    required this.messageType,
    this.replyToId,
    this.editedAt,
    this.deletedAt,
    required this.createdAt,
    this.sender,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as int,
        roomId: j['room_id'] as int,
        senderUserId: j['sender_user_id'] as int,
        body: (j['body'] as String?) ?? '',
        messageType: (j['message_type'] as String?) ?? 'text',
        replyToId: j['reply_to_id'] as int?,
        editedAt: j['edited_at'] != null ? DateTime.tryParse(j['edited_at'].toString()) : null,
        deletedAt: j['deleted_at'] != null ? DateTime.tryParse(j['deleted_at'].toString()) : null,
        createdAt: DateTime.parse(j['created_at']?.toString() ?? DateTime.now().toIso8601String()),
        sender: j['sender'] != null ? ChatUser.fromJson(Map<String, dynamic>.from(j['sender'])) : null,
      );
}

class ChatRoom {
  final int id;
  final String type; // direct | task | group
  final int? taskId;
  final String? name;
  final int createdByUserId;
  final DateTime? lastMessageAt;
  final List<ChatMember> members;
  final ChatMessage? lastMessage;
  final int unreadCount;

  ChatRoom({
    required this.id,
    required this.type,
    this.taskId,
    this.name,
    required this.createdByUserId,
    this.lastMessageAt,
    required this.members,
    this.lastMessage,
    required this.unreadCount,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> j) {
    final membersList = (j['members'] as List?) ?? [];
    Map<String, dynamic>? lm;
    if (j['last_message'] is Map) {
      lm = Map<String, dynamic>.from(j['last_message']);
    }
    return ChatRoom(
      id: j['id'] as int,
      type: (j['type'] as String?) ?? 'direct',
      taskId: j['task_id'] as int?,
      name: j['name'] as String?,
      createdByUserId: j['created_by_user_id'] as int,
      lastMessageAt: j['last_message_at'] != null
          ? DateTime.tryParse(j['last_message_at'].toString())
          : null,
      members: membersList
          .map((m) => ChatMember.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      lastMessage: lm != null ? ChatMessage.fromJson(lm) : null,
      unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Display name: for direct = other user's name; otherwise the explicit name
  String displayName(int currentUserId) {
    if (type == 'direct') {
      final other = members.firstWhere(
        (m) => m.userId != currentUserId,
        orElse: () => members.isNotEmpty ? members.first : ChatMember(id: 0, roomId: id, userId: 0),
      );
      return other.user?.name ?? 'Direct chat';
    }
    return name ?? (type == 'task' ? 'Task discussion' : 'Group');
  }
}
