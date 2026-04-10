import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../../../core/networking/dio_client.dart';
import '../services/socket_service.dart';

final _logger = Logger();

// ============================================================================
// SERVICE PROVIDERS
// ============================================================================

/// Provider for NotificationService
final notificationServiceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationService(dio);
});

/// Provider for SocketService (singleton)
final socketServiceProvider = Provider((ref) {
  return SocketService();
});

// ============================================================================
// STATE CLASSES
// ============================================================================

class NotificationListState {
  final List<NotificationModel> notifications;
  final int total;
  final int currentPage;
  final int itemsPerPage;
  final bool isLoading;
  final String? error;
  final String filter; // 'all', 'read', 'unread'

  NotificationListState({
    this.notifications = const [],
    this.total = 0,
    this.currentPage = 1,
    this.itemsPerPage = 20,
    this.isLoading = false,
    this.error,
    this.filter = 'all',
  });

  NotificationListState copyWith({
    List<NotificationModel>? notifications,
    int? total,
    int? currentPage,
    int? itemsPerPage,
    bool? isLoading,
    String? error,
    String? filter,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filter: filter ?? this.filter,
    );
  }

  int get totalPages => (total / itemsPerPage).ceil();
  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
  int get unreadCount => notifications.where((n) => !n.read).length;
}

// ============================================================================
// NOTIFIERS (Riverpod 3.x Notifier pattern)
// ============================================================================

class NotificationListNotifier extends Notifier<NotificationListState> {
  @override
  NotificationListState build() {
    final socketService = ref.watch(socketServiceProvider);
    _setupSocketListeners(socketService);
    return NotificationListState();
  }

  NotificationService get _service => ref.read(notificationServiceProvider);

  /// Setup Socket.io listeners for real-time updates
  void _setupSocketListeners(SocketService socketService) {
    socketService.onNotification((notification) {
      _logger.i('Received new notification via socket');
      state = state.copyWith(
        notifications: [notification, ...state.notifications],
        total: state.total + 1,
      );
    });

    socketService.onNotificationUpdate((notificationId, isRead) {
      _logger.i('Notification $notificationId updated to isRead=$isRead');
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(read: isRead);
        }
        return n;
      }).toList();
      state = state.copyWith(notifications: updatedNotifications);
    });
  }

  /// Fetch notifications with pagination
  Future<void> fetchNotifications({
    int page = 1,
    String filter = 'all',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.getNotifications(
        page: page,
        limit: state.itemsPerPage,
        filter: filter,
      );

      state = state.copyWith(
        notifications: result.notifications,
        total: result.total,
        currentPage: result.page,
        itemsPerPage: result.limit,
        isLoading: false,
        filter: filter,
      );
    } catch (e) {
      _logger.e('Error fetching notifications: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications',
      );
    }
  }

  /// Load next page
  Future<void> loadNextPage() async {
    if (!state.hasNextPage) return;
    await fetchNotifications(page: state.currentPage + 1, filter: state.filter);
  }

  /// Load previous page
  Future<void> loadPreviousPage() async {
    if (!state.hasPreviousPage) return;
    await fetchNotifications(page: state.currentPage - 1, filter: state.filter);
  }

  /// Mark a notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      await _service.markAsRead(notificationId);
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(read: true, readAt: DateTime.now());
          }
          return n;
        }).toList(),
      );
    } catch (e) {
      _logger.e('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          return n.copyWith(read: true, readAt: DateTime.now());
        }).toList(),
      );
    } catch (e) {
      _logger.e('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(int notificationId) async {
    try {
      await _service.deleteNotification(notificationId);
      state = state.copyWith(
        notifications: state.notifications.where((n) => n.id != notificationId).toList(),
        total: state.total - 1,
      );
    } catch (e) {
      _logger.e('Error deleting notification: $e');
    }
  }

  /// Delete all read notifications
  Future<void> deleteReadNotifications() async {
    try {
      await _service.deleteReadNotifications();
      state = state.copyWith(
        notifications: state.notifications.where((n) => !n.read).toList(),
        total: state.notifications.where((n) => !n.read).length,
      );
    } catch (e) {
      _logger.e('Error deleting read notifications: $e');
    }
  }
}

/// Notification list provider
final notificationListProvider =
    NotifierProvider<NotificationListNotifier, NotificationListState>(
        NotificationListNotifier.new);

// ============================================================================
// UNREAD COUNT
// ============================================================================

class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() {
    final socketService = ref.watch(socketServiceProvider);
    _setupSocketListeners(socketService);
    return 0;
  }

  NotificationService get _service => ref.read(notificationServiceProvider);

  void _setupSocketListeners(SocketService socketService) {
    socketService.onUnreadCountChange((count) {
      _logger.i('Unread count changed to: $count');
      state = count;
    });
  }

  Future<void> fetchUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      state = count;
    } catch (e) {
      _logger.e('Error fetching unread count: $e');
    }
  }

  void decrementCount() {
    if (state > 0) state = state - 1;
  }

  void incrementCount() {
    state = state + 1;
  }

  void setCount(int count) {
    state = count;
  }
}

/// Unread count provider
final unreadCountProvider =
    NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);

// ============================================================================
// NOTIFICATION SETTINGS
// ============================================================================

class NotificationSettingsNotifier extends Notifier<NotificationPreferenceModel?> {
  @override
  NotificationPreferenceModel? build() => null;

  NotificationService get _service => ref.read(notificationServiceProvider);

  Future<void> fetchPreferences() async {
    try {
      final preferences = await _service.getPreferences();
      state = preferences;
    } catch (e) {
      _logger.e('Error fetching notification preferences: $e');
    }
  }

  Future<void> updatePreferences(NotificationPreferenceModel preferences) async {
    try {
      final updated = await _service.updatePreferences(preferences);
      state = updated;
    } catch (e) {
      _logger.e('Error updating notification preferences: $e');
      rethrow;
    }
  }
}

/// Notification settings provider
final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationPreferenceModel?>(
        NotificationSettingsNotifier.new);

// ============================================================================
// INITIALIZATION PROVIDER
// ============================================================================

/// Async provider to initialize socket and fetch initial notification data.
/// Should be read/watched after auth is confirmed (e.g. in AppShell).
final notificationInitializationProvider = FutureProvider<void>((ref) async {
  try {
    // Fetch initial data in parallel for faster startup
    await Future.wait([
      ref.read(unreadCountProvider.notifier).fetchUnreadCount(),
      ref.read(notificationListProvider.notifier).fetchNotifications(page: 1),
      ref.read(notificationSettingsProvider.notifier).fetchPreferences(),
    ]);
    _logger.i('Notification initialization completed');
  } catch (e) {
    _logger.e('Error initializing notifications: $e');
  }
});
