import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/networking/dio_client.dart';
import '../../notifications/services/socket_service.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatService(dio);
});

// ── Rooms list ──────────────────────────────────────────────────────────────

class ChatRoomsState {
  final List<ChatRoom> rooms;
  final bool loading;
  final String? error;

  const ChatRoomsState({this.rooms = const [], this.loading = false, this.error});

  ChatRoomsState copyWith({List<ChatRoom>? rooms, bool? loading, String? error}) =>
      ChatRoomsState(
        rooms: rooms ?? this.rooms,
        loading: loading ?? this.loading,
        error: error,
      );
}

class ChatRoomsNotifier extends Notifier<ChatRoomsState> {
  late final ChatService _service;
  void Function()? _disposeMsg;
  void Function()? _disposeRoom;

  @override
  ChatRoomsState build() {
    _service = ref.watch(chatServiceProvider);
    final socket = SocketService();
    _disposeMsg = socket.onChatMessage((_) => refresh());
    _disposeRoom = socket.onChatRoomUpdate((_) => refresh());
    ref.onDispose(() {
      _disposeMsg?.call();
      _disposeRoom?.call();
    });
    Future.microtask(refresh);
    return const ChatRoomsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final rooms = await _service.listRooms();
      state = state.copyWith(rooms: rooms, loading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.response?.data?['message']?.toString() ?? 'Failed to load chats',
      );
    }
  }

  Future<ChatRoom> openDirect(int userId) async {
    final room = await _service.openDirectRoom(userId);
    await refresh();
    return room;
  }

  Future<ChatRoom> openTask(int taskId) async {
    final room = await _service.openTaskRoom(taskId);
    await refresh();
    return room;
  }

  Future<ChatRoom> createGroup(String name, List<int> memberIds) async {
    final room = await _service.createGroup(name, memberIds);
    await refresh();
    return room;
  }
}

final chatRoomsProvider =
    NotifierProvider<ChatRoomsNotifier, ChatRoomsState>(() => ChatRoomsNotifier());

// ── Unread count ────────────────────────────────────────────────────────────

class ChatUnreadNotifier extends Notifier<int> {
  late final ChatService _service;
  void Function()? _disposeMsg;
  Timer? _debounce;

  @override
  int build() {
    _service = ref.watch(chatServiceProvider);
    final socket = SocketService();
    _disposeMsg = socket.onChatMessage((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), refresh);
    });
    ref.onDispose(() {
      _disposeMsg?.call();
      _debounce?.cancel();
    });
    Future.microtask(refresh);
    return 0;
  }

  Future<void> refresh() async {
    try {
      state = await _service.getUnreadCount();
    } catch (_) {}
  }
}

final chatUnreadProvider =
    NotifierProvider<ChatUnreadNotifier, int>(() => ChatUnreadNotifier());

// ── Single-room messages ────────────────────────────────────────────────────

class ChatRoomState {
  final List<ChatMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final Set<int> typingUserIds;
  final ChatMessage? replyTarget;

  const ChatRoomState({
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.error,
    this.typingUserIds = const {},
    this.replyTarget,
  });

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    String? error,
    Set<int>? typingUserIds,
    ChatMessage? replyTarget,
    bool clearReply = false,
  }) =>
      ChatRoomState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: error,
        typingUserIds: typingUserIds ?? this.typingUserIds,
        replyTarget: clearReply ? null : (replyTarget ?? this.replyTarget),
      );
}

class ChatRoomNotifier extends Notifier<ChatRoomState> {
  ChatRoomNotifier(this.roomId);
  final int roomId;

  late final ChatService _service;
  late final SocketService _socket;
  void Function()? _disposeMsg;
  void Function()? _disposeEdit;
  void Function()? _disposeDel;
  void Function()? _disposeTyping;
  void Function()? _disposeReaction;
  void Function()? _disposePin;
  Timer? _typingClearTimer;

  @override
  ChatRoomState build() {
    _service = ref.watch(chatServiceProvider);
    _socket = SocketService();

    _disposeMsg = _socket.onChatMessage((data) {
      if ((data['room_id'] as int?) != roomId) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      // De-dupe (we may have already pushed the message ourselves after POST)
      if (state.messages.any((m) => m.id == msg.id)) return;
      state = state.copyWith(messages: [...state.messages, msg]);
      // Auto-mark read
      _service.markRead(roomId).catchError((_) {});
    });

    _disposeEdit = _socket.onChatMessageEdited((data) {
      if ((data['room_id'] as int?) != roomId) return;
      final updated = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      state = state.copyWith(
        messages: state.messages.map((m) => m.id == updated.id ? updated : m).toList(),
      );
    });

    _disposeDel = _socket.onChatMessageDeleted((data) {
      if ((data['room_id'] as int?) != roomId) return;
      final id = data['id'] as int?;
      if (id == null) return;
      state = state.copyWith(messages: state.messages.where((m) => m.id != id).toList());
    });

    _disposeTyping = _socket.onChatTyping((data) {
      if ((data['room_id'] as int?) != roomId) return;
      final uid = data['user_id'] as int?;
      final typing = data['typing'] as bool? ?? true;
      if (uid == null) return;
      final next = {...state.typingUserIds};
      if (typing) {
        next.add(uid);
      } else {
        next.remove(uid);
      }
      state = state.copyWith(typingUserIds: next);
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 4), () {
        state = state.copyWith(typingUserIds: const {});
      });
    });

    _disposeReaction = _socket.onChatReaction((data) {
      if ((data['room_id'] as int?) != roomId) return;
      final messageId = data['message_id'] as int?;
      if (messageId == null) return;
      final reactionsList = (data['reactions'] as List?) ?? [];
      final reactions = reactionsList
          .map((r) => ChatReaction.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == messageId ? m.copyWith(reactions: reactions) : m)
            .toList(),
      );
    });

    _disposePin = _socket.onChatPin((data) {
      final updated = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      if (updated.roomId != roomId) return;
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == updated.id ? updated : m)
            .toList(),
      );
    });

    _socket.joinChatRoom(roomId);

    ref.onDispose(() {
      _disposeMsg?.call();
      _disposeEdit?.call();
      _disposeDel?.call();
      _disposeTyping?.call();
      _disposeReaction?.call();
      _disposePin?.call();
      _typingClearTimer?.cancel();
      _socket.leaveChatRoom(roomId);
    });

    Future.microtask(refresh);
    return const ChatRoomState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final messages = await _service.getMessages(roomId);
      state = state.copyWith(messages: messages, loading: false);
      _service.markRead(roomId).catchError((_) {});
    } on DioException catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.response?.data?['message']?.toString() ?? 'Failed to load messages',
      );
    }
  }

  void setReplyTarget(ChatMessage? target) {
    state = state.copyWith(replyTarget: target, clearReply: target == null);
  }

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || state.sending) return;
    final replyId = state.replyTarget?.id;
    state = state.copyWith(sending: true, error: null);
    try {
      final msg = await _service.sendMessage(roomId, trimmed, replyToId: replyId);
      if (!state.messages.any((m) => m.id == msg.id)) {
        state = state.copyWith(
          messages: [...state.messages, msg],
          sending: false,
          clearReply: true,
        );
      } else {
        state = state.copyWith(sending: false, clearReply: true);
      }
    } on DioException catch (e) {
      state = state.copyWith(
        sending: false,
        error: e.response?.data?['message']?.toString() ?? 'Failed to send',
      );
    }
  }

  void emitTyping(bool typing) => _socket.emitTyping(roomId, typing);

  Future<void> sendWithAttachment({
    required Uint8List bytes,
    required String filename,
    String? caption,
  }) async {
    if (state.sending) return;
    final replyId = state.replyTarget?.id;
    state = state.copyWith(sending: true, error: null);
    try {
      final msg = await _service.sendWithAttachment(
        roomId: roomId,
        bytes: bytes,
        filename: filename,
        caption: caption,
        replyToId: replyId,
      );
      if (!state.messages.any((m) => m.id == msg.id)) {
        state = state.copyWith(
          messages: [...state.messages, msg],
          sending: false,
          clearReply: true,
        );
      } else {
        state = state.copyWith(sending: false, clearReply: true);
      }
    } on DioException catch (e) {
      state = state.copyWith(
        sending: false,
        error: e.response?.data?['message']?.toString() ?? 'Failed to upload',
      );
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      await _service.deleteMessage(messageId);
      state =
          state.copyWith(messages: state.messages.where((m) => m.id != messageId).toList());
    } on DioException catch (e) {
      state = state.copyWith(
        error: e.response?.data?['message']?.toString() ?? 'Failed to delete',
      );
    }
  }

  Future<void> toggleReaction(int messageId, String emoji) async {
    try {
      final reactions = await _service.toggleReaction(messageId, emoji);
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == messageId ? m.copyWith(reactions: reactions) : m)
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> togglePin(int messageId, bool pin) async {
    try {
      final updated = pin
          ? await _service.pinMessage(messageId)
          : await _service.unpinMessage(messageId);
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == messageId ? updated : m)
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> forward(int messageId, int targetRoomId) async {
    try {
      await _service.forwardMessage(messageId, targetRoomId);
    } catch (_) {}
  }
}

final chatRoomProvider =
    NotifierProvider.family<ChatRoomNotifier, ChatRoomState, int>(
        (roomId) => ChatRoomNotifier(roomId));

// ── Presence (online users) ─────────────────────────────────────────────────

class ChatPresenceNotifier extends Notifier<Set<int>> {
  void Function()? _dispose;

  @override
  Set<int> build() {
    final socket = SocketService();
    _dispose = socket.onPresence((data) {
      final kind = data['kind'] as String?;
      if (kind == 'snapshot') {
        final list = (data['online'] as List?) ?? [];
        state = list.map((e) => (e as num).toInt()).toSet();
      } else if (kind == 'online') {
        final uid = data['user_id'] as int?;
        if (uid != null) state = {...state, uid};
      } else if (kind == 'offline') {
        final uid = data['user_id'] as int?;
        if (uid != null) state = state.where((u) => u != uid).toSet();
      }
    });
    ref.onDispose(() => _dispose?.call());
    return const <int>{};
  }
}

final chatPresenceProvider =
    NotifierProvider<ChatPresenceNotifier, Set<int>>(() => ChatPresenceNotifier());

bool isUserOnline(WidgetRef ref, int userId) =>
    ref.watch(chatPresenceProvider).contains(userId);

// ── Per-room read receipts (member last_read_at map) ────────────────────────

class ChatRoomReadsNotifier extends Notifier<Map<int, DateTime?>> {
  ChatRoomReadsNotifier(this.roomId);
  final int roomId;
  late final ChatService _service;
  void Function()? _disposeRead;

  @override
  Map<int, DateTime?> build() {
    _service = ref.watch(chatServiceProvider);
    final socket = SocketService();
    _disposeRead = socket.onChatRead((data) {
      if ((data['room_id'] as int?) != roomId) return;
      final uid = data['user_id'] as int?;
      final at = data['read_at'] != null
          ? DateTime.tryParse(data['read_at'].toString())
          : null;
      if (uid != null) state = {...state, uid: at};
    });
    ref.onDispose(() => _disposeRead?.call());
    Future.microtask(refresh);
    return const <int, DateTime?>{};
  }

  Future<void> refresh() async {
    try {
      final members = await _service.listMembers(roomId);
      final map = <int, DateTime?>{};
      for (final m in members) {
        map[m.userId] = m.lastReadAt;
      }
      state = map;
    } catch (_) {}
  }
}

final chatRoomReadsProvider = NotifierProvider.family<ChatRoomReadsNotifier,
    Map<int, DateTime?>, int>((roomId) => ChatRoomReadsNotifier(roomId));

// ── Per-room members (for group info screen) ────────────────────────────────

class ChatMembersState {
  final List<ChatMember> members;
  final bool loading;
  final String? error;
  const ChatMembersState({this.members = const [], this.loading = false, this.error});

  ChatMembersState copyWith({List<ChatMember>? members, bool? loading, String? error}) =>
      ChatMembersState(
        members: members ?? this.members,
        loading: loading ?? this.loading,
        error: error,
      );
}

class ChatMembersNotifier extends Notifier<ChatMembersState> {
  ChatMembersNotifier(this.roomId);
  final int roomId;
  late final ChatService _service;

  @override
  ChatMembersState build() {
    _service = ref.watch(chatServiceProvider);
    Future.microtask(refresh);
    return const ChatMembersState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final members = await _service.listMembers(roomId);
      state = state.copyWith(members: members, loading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.response?.data?['message']?.toString() ?? 'Failed to load members',
      );
    }
  }

  Future<void> addMember(int userId) async {
    await _service.addMember(roomId, userId);
    await refresh();
  }

  Future<void> removeMember(int userId) async {
    await _service.removeMember(roomId, userId);
    await refresh();
  }
}

final chatMembersProvider = NotifierProvider.family<ChatMembersNotifier,
    ChatMembersState, int>((roomId) => ChatMembersNotifier(roomId));

// ── Pinned messages ─────────────────────────────────────────────────────────

class ChatPinnedNotifier extends Notifier<List<ChatMessage>> {
  ChatPinnedNotifier(this.roomId);
  final int roomId;
  late final ChatService _service;
  void Function()? _disposePin;

  @override
  List<ChatMessage> build() {
    _service = ref.watch(chatServiceProvider);
    final socket = SocketService();
    _disposePin = socket.onChatPin((_) => refresh());
    ref.onDispose(() => _disposePin?.call());
    Future.microtask(refresh);
    return const [];
  }

  Future<void> refresh() async {
    try {
      final list = await _service.listPinned(roomId);
      state = list;
    } catch (_) {}
  }
}

final chatPinnedProvider = NotifierProvider.family<ChatPinnedNotifier,
    List<ChatMessage>, int>((roomId) => ChatPinnedNotifier(roomId));

// ── Search ──────────────────────────────────────────────────────────────────

final chatSearchProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  final svc = ref.watch(chatServiceProvider);
  return svc.search(query);
});
