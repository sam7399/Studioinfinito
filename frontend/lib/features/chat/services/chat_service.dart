import 'dart:js_interop';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:web/web.dart' as web;
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/token_service.dart';
import '../models/chat_models.dart';

class ChatService {
  final Dio _dio;
  ChatService(this._dio);

  String attachmentUrl(int attachmentId) =>
      '${ApiConstants.baseUrl}${ApiConstants.chatAttachmentById(attachmentId)}';

  Map<String, String> authHeaders() {
    final t = TokenService.instance.token;
    return t == null ? {} : {'Authorization': 'Bearer $t'};
  }

  Future<List<ChatRoom>> listRooms() async {
    final res = await _dio.get(ApiConstants.chatRooms);
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((j) => ChatRoom.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final res = await _dio.get(ApiConstants.chatUnreadCount);
    final data = res.data['data'] as Map<String, dynamic>?;
    return (data?['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<ChatRoom> openDirectRoom(int userId) async {
    final res = await _dio.post(ApiConstants.chatDirectRoom, data: {'user_id': userId});
    return ChatRoom.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<ChatRoom> openTaskRoom(int taskId) async {
    final res = await _dio.post(ApiConstants.chatTaskRoom(taskId));
    return ChatRoom.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<List<ChatMessage>> getMessages(int roomId, {int? beforeId, int limit = 50}) async {
    final qp = <String, dynamic>{'limit': limit};
    if (beforeId != null) qp['before_id'] = beforeId;
    final res = await _dio.get(ApiConstants.chatRoomMessages(roomId), queryParameters: qp);
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  Future<ChatMessage> sendMessage(int roomId, String body, {int? replyToId}) async {
    final res = await _dio.post(
      ApiConstants.chatRoomMessages(roomId),
      data: {
        'body': body,
        'message_type': 'text',
        if (replyToId != null) 'reply_to_id': replyToId,
      },
    );
    return ChatMessage.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<void> markRead(int roomId) async {
    await _dio.post(ApiConstants.chatRoomRead(roomId));
  }

  Future<void> editMessage(int messageId, String body) async {
    await _dio.patch(ApiConstants.chatMessageById(messageId), data: {'body': body});
  }

  Future<void> deleteMessage(int messageId) async {
    await _dio.delete(ApiConstants.chatMessageById(messageId));
  }

  Future<ChatMessage> sendWithAttachment({
    required int roomId,
    required Uint8List bytes,
    required String filename,
    String? caption,
    int? replyToId,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      if (caption != null && caption.isNotEmpty) 'body': caption,
      if (replyToId != null) 'reply_to_id': replyToId.toString(),
    });
    final res = await _dio.post(
      ApiConstants.chatRoomMessagesUpload(roomId),
      data: form,
    );
    return ChatMessage.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  /// Fetch raw bytes of an attachment (Dio sends auth header).
  Future<Uint8List> fetchAttachmentBytes(int attachmentId) async {
    final res = await _dio.get<List<int>>(
      ApiConstants.chatAttachmentById(attachmentId),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const <int>[]);
  }

  /// Trigger a browser download for an attachment.
  /// Uses Dio (so the auth header is sent) and creates a Blob link.
  Future<void> openAttachment(int attachmentId, String filename) async {
    final res = await _dio.get<List<int>>(
      ApiConstants.chatAttachmentById(attachmentId),
      queryParameters: {'inline': 'false'},
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = res.data ?? const <int>[];
    final blob = web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: 'application/octet-stream'),
    );
    final url = web.URL.createObjectURL(blob);
    (web.document.createElement('a') as web.HTMLAnchorElement)
      ..href = url
      ..setAttribute('download', filename)
      ..click();
    web.URL.revokeObjectURL(url);
  }

  Future<ChatRoom> createGroup(String name, List<int> memberIds) async {
    final res = await _dio.post(
      ApiConstants.chatGroupRoom,
      data: {'name': name, 'member_ids': memberIds},
    );
    return ChatRoom.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<List<ChatMember>> listMembers(int roomId) async {
    final res = await _dio.get(ApiConstants.chatRoomMembers(roomId));
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((j) => ChatMember.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  Future<void> addMember(int roomId, int userId) async {
    await _dio.post(ApiConstants.chatRoomMembers(roomId), data: {'user_id': userId});
  }

  Future<void> removeMember(int roomId, int userId) async {
    await _dio.delete(ApiConstants.chatRoomMemberById(roomId, userId));
  }

  Future<List<ChatReaction>> toggleReaction(int messageId, String emoji) async {
    final res = await _dio.post(
      ApiConstants.chatMessageReactions(messageId),
      data: {'emoji': emoji},
    );
    final list = (res.data['data']?['reactions'] as List?) ?? [];
    return list
        .map((r) => ChatReaction.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<ChatMessage> pinMessage(int messageId) async {
    final res = await _dio.post(ApiConstants.chatMessagePin(messageId));
    return ChatMessage.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<ChatMessage> unpinMessage(int messageId) async {
    final res = await _dio.delete(ApiConstants.chatMessagePin(messageId));
    return ChatMessage.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<List<ChatMessage>> listPinned(int roomId) async {
    final res = await _dio.get(ApiConstants.chatRoomPinned(roomId));
    final list = (res.data['data'] as List?) ?? [];
    return list
        .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
  }

  Future<ChatMessage> forwardMessage(int messageId, int targetRoomId) async {
    final res = await _dio.post(
      ApiConstants.chatMessageForward(messageId),
      data: {'room_id': targetRoomId},
    );
    return ChatMessage.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<List<Map<String, dynamic>>> search(String query, {int? roomId, int limit = 30}) async {
    final res = await _dio.get(
      ApiConstants.chatSearch,
      queryParameters: {
        'q': query,
        if (roomId != null) 'room_id': roomId,
        'limit': limit,
      },
    );
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
