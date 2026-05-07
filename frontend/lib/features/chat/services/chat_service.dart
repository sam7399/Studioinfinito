import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../models/chat_models.dart';

class ChatService {
  final Dio _dio;
  ChatService(this._dio);

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
}
