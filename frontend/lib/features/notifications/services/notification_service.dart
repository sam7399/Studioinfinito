import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/notification_model.dart';
import '../../../core/constants/api_constants.dart';

/// Service for handling notification API calls
class NotificationService {
  final Dio _dio;
  final Logger _logger = Logger();

  NotificationService(this._dio);

  /// Get paginated list of notifications for the current user
  /// 
  /// Parameters:
  /// - page: Page number (default 1)
  /// - limit: Number of notifications per page (default 20)
  /// - filter: Filter by read status ('all', 'read', 'unread')
  Future<({List<NotificationModel> notifications, int total, int page, int limit})>
      getNotifications({
    int page = 1,
    int limit = 20,
    String filter = 'all',
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.notifications,
        queryParameters: {
          'page': page,
          'limit': limit,
          'filter': filter,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final notificationsList = (data['notifications'] as List)
          .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
          .toList();

      return (
        notifications: notificationsList,
        total: data['total'] as int,
        page: data['page'] as int,
        limit: data['limit'] as int,
      );
    } on DioException catch (e) {
      _logger.e('Failed to fetch notifications', error: e);
      rethrow;
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.notifications}/count',
      );
      return response.data['data']['count'] as int;
    } on DioException catch (e) {
      _logger.e('Failed to fetch unread count', error: e);
      rethrow;
    }
  }

  /// Mark a single notification as read
  Future<NotificationModel> markAsRead(int notificationId) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.notifications}/$notificationId/read',
      );
      return NotificationModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _logger.e('Failed to mark notification as read', error: e);
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _dio.put(
        '${ApiConstants.notifications}/mark-all-read',
      );
    } on DioException catch (e) {
      _logger.e('Failed to mark all notifications as read', error: e);
      rethrow;
    }
  }

  /// Delete a single notification
  Future<void> deleteNotification(int notificationId) async {
    try {
      await _dio.delete(
        '${ApiConstants.notifications}/$notificationId',
      );
    } on DioException catch (e) {
      _logger.e('Failed to delete notification', error: e);
      rethrow;
    }
  }

  /// Delete all read notifications
  Future<void> deleteReadNotifications() async {
    try {
      await _dio.delete(
        '${ApiConstants.notifications}/delete-read',
      );
    } on DioException catch (e) {
      _logger.e('Failed to delete read notifications', error: e);
      rethrow;
    }
  }

  /// Get notification preferences
  Future<NotificationPreferenceModel> getPreferences() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.notifications}/preferences',
      );
      return NotificationPreferenceModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _logger.e('Failed to fetch notification preferences', error: e);
      rethrow;
    }
  }

  /// Update notification preferences
  Future<NotificationPreferenceModel> updatePreferences(
    NotificationPreferenceModel preferences,
  ) async {
    try {
      final response = await _dio.put(
        '${ApiConstants.notifications}/preferences',
        data: {
          'taskAssigned': preferences.taskAssigned,
          'taskCompleted': preferences.taskCompleted,
          'taskCommented': preferences.taskCommented,
          'taskDeadlineApproaching': preferences.taskDeadlineApproaching,
          'taskStatusChanged': preferences.taskStatusChanged,
          'taskReviewPending': preferences.taskReviewPending,
          'taskReviewApproved': preferences.taskReviewApproved,
          'taskReviewRejected': preferences.taskReviewRejected,
          'emailNotifications': preferences.emailNotifications,
          'pushNotifications': preferences.pushNotifications,
        },
      );
      return NotificationPreferenceModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      _logger.e('Failed to update notification preferences', error: e);
      rethrow;
    }
  }
}
