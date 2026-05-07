import 'dart:async';
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

  const ChatRoomState({
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.error,
    this.typingUserIds = const {},
  });

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? sending,
    String? error,
    Set<int>? typingUserIds,
  }) =>
      ChatRoomState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: error,
        typingUserIds: typingUserIds ?? this.typingUserIds,
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

    _socket.joinChatRoom(roomId);

    ref.onDispose(() {
      _disposeMsg?.call();
      _disposeEdit?.call();
      _disposeDel?.call();
      _disposeTyping?.call();
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

  Future<void> send(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || state.sending) return;
    state = state.copyWith(sending: true, error: null);
    try {
      final msg = await _service.sendMessage(roomId, trimmed);
      // Optimistically add (socket may also dispatch — de-dupe via id check)
      if (!state.messages.any((m) => m.id == msg.id)) {
        state = state.copyWith(messages: [...state.messages, msg], sending: false);
      } else {
        state = state.copyWith(sending: false);
      }
    } on DioException catch (e) {
      state = state.copyWith(
        sending: false,
        error: e.response?.data?['message']?.toString() ?? 'Failed to send',
      );
    }
  }

  void emitTyping(bool typing) => _socket.emitTyping(roomId, typing);

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
}

final chatRoomProvider =
    NotifierProvider.family<ChatRoomNotifier, ChatRoomState, int>(
        (roomId) => ChatRoomNotifier(roomId));
