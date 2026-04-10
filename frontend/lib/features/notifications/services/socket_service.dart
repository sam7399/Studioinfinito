import 'dart:async';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../core/networking/token_service.dart';
import '../models/notification_model.dart';

/// Callback for new notifications
typedef OnNotificationCallback = void Function(NotificationModel notification);

/// Callback for notification update (mark as read, etc)
typedef OnNotificationUpdateCallback = void Function(int notificationId, bool isRead);

/// Callback for unread count change
typedef OnUnreadCountCallback = void Function(int count);

/// Generic callback for data-change events (task updates, user updates, etc.)
typedef OnDataChangeCallback = void Function(Map<String, dynamic> data);

/// Service for managing WebSocket connection and real-time notifications.
///
/// Singleton — use `SocketService()` everywhere.
/// Call [initialize] after login / session restore, [disconnect] on logout.
class SocketService {
  static final SocketService _instance = SocketService._internal();

  IO.Socket? _socket;
  final Logger _logger = Logger();

  // ── Notification callbacks ──────────────────────────────────────────────
  OnNotificationCallback? _onNotification;
  OnNotificationUpdateCallback? _onNotificationUpdate;
  OnUnreadCountCallback? _onUnreadCountChange;

  // ── Data-change callbacks ──────────────────────────────────────────────
  final List<OnDataChangeCallback> _onTaskUpdateCallbacks = [];
  final List<OnDataChangeCallback> _onUserUpdateCallbacks = [];
  final List<OnDataChangeCallback> _onApprovalUpdateCallbacks = [];

  // ── Connection state ───────────────────────────────────────────────────
  bool _isConnected = false;
  bool _isInitialized = false;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final int _initialReconnectDelay = 1000; // ms

  // ── Polling fallback ───────────────────────────────────────────────────
  Timer? _pollingTimer;
  bool _pollingActive = false;
  VoidCallbackAsync? _onPollTick;

  SocketService._internal();

  factory SocketService() => _instance;

  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  bool get isPollingActive => _pollingActive;

  // ════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ════════════════════════════════════════════════════════════════════════

  /// Initialize the Socket.io connection.
  ///
  /// [baseUrl] – Socket.io server URL (e.g. 'http://localhost:5000')
  /// [token]   – JWT token for authentication
  Future<void> initialize(String baseUrl, String? token) async {
    if (_isConnected && _isInitialized) {
      _logger.w('Socket already connected, skipping initialization');
      return;
    }

    // Dispose old socket if any (e.g. token changed)
    if (_socket != null) {
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
      _isConnected = false;
      _isInitialized = false;
    }

    try {
      _logger.i('Initializing Socket.io connection to: $baseUrl');

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling']) // allow polling fallback
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(10000)
            .setReconnectionAttempts(10)
            .setAuth({'token': token ?? ''})
            .setExtraHeaders({
              'Authorization': token != null ? 'Bearer $token' : '',
            })
            .build(),
      );

      _setupEventListeners();
      _isInitialized = true;
      _reconnectAttempts = 0;

      _logger.i('Socket.io connection initialized');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize Socket.io connection',
          error: e, stackTrace: stackTrace);
      // Fall back to polling
      _startPollingFallback();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // EVENT LISTENERS
  // ════════════════════════════════════════════════════════════════════════

  void _setupEventListeners() {
    final socket = _socket;
    if (socket == null) return;

    // ── Connection lifecycle ──────────────────────────────────────────────
    socket.on('connect', (_) {
      _logger.i('Socket connected');
      _isConnected = true;
      _reconnectAttempts = 0;

      // Stop polling if we successfully connected via WS
      _stopPollingFallback();

      // Subscribe to user's personal room
      _subscribeToNotifications();
    });

    socket.on('disconnect', (_) {
      _logger.i('Socket disconnected');
      _isConnected = false;
      // Start polling fallback after disconnect
      _startPollingFallback();
    });

    socket.on('connect_error', (error) {
      _logger.e('Socket connection error: $error');
      _isConnected = false;
      // Start polling fallback on connection error
      _startPollingFallback();
    });

    socket.on('reconnect', (_) {
      _logger.i('Socket reconnected');
      _isConnected = true;
      _stopPollingFallback();
      _subscribeToNotifications();
    });

    // ── Notification events ──────────────────────────────────────────────
    // Backend emits 'notification:new' via emitToUser
    socket.on('notification:new', _handleNotificationEvent);
    // Also listen for legacy 'notification' event
    socket.on('notification', _handleNotificationEvent);

    // Notification update events
    socket.on('notification:updated', (data) {
      try {
        _logger.i('Received notification update event');
        if (data is Map<String, dynamic>) {
          final notificationId = data['notificationId'] as int?;
          final isRead = data['isRead'] as bool?;
          if (notificationId != null && isRead != null) {
            _onNotificationUpdate?.call(notificationId, isRead);
          }
        }
      } catch (e, stackTrace) {
        _logger.e('Error processing notification update event',
            error: e, stackTrace: stackTrace);
      }
    });

    // Unread count change events
    socket.on('unread:count', (data) {
      try {
        if (data is Map<String, dynamic>) {
          final count = data['count'] as int?;
          if (count != null) _onUnreadCountChange?.call(count);
        }
      } catch (e, stackTrace) {
        _logger.e('Error processing unread count event',
            error: e, stackTrace: stackTrace);
      }
    });

    // ── Task events ──────────────────────────────────────────────────────
    // Backend emits 'task:update' via emitTaskUpdate
    socket.on('task:update', _handleTaskUpdateEvent);
    // Also listen for alternate event names
    socket.on('task:updated', _handleTaskUpdateEvent);
    socket.on('task:created', _handleTaskUpdateEvent);
    socket.on('task:deleted', _handleTaskUpdateEvent);
    socket.on('task:assigned', _handleTaskUpdateEvent);
    socket.on('task:completed', _handleTaskUpdateEvent);
    socket.on('task:status_changed', _handleTaskUpdateEvent);

    // ── Approval events ──────────────────────────────────────────────────
    socket.on('task_approval_pending', _handleApprovalUpdateEvent);
    socket.on('task_approval_approved', _handleApprovalUpdateEvent);
    socket.on('task_approval_rejected', _handleApprovalUpdateEvent);
    socket.on('approval:pending', _handleApprovalUpdateEvent);
    socket.on('approval:updated', _handleApprovalUpdateEvent);

    // ── User events ──────────────────────────────────────────────────────
    socket.on('user:created', _handleUserUpdateEvent);
    socket.on('user:updated', _handleUserUpdateEvent);
    socket.on('user:deleted', _handleUserUpdateEvent);

    // ── Error handling ───────────────────────────────────────────────────
    socket.on('error', (error) {
      _logger.e('Socket error: $error');
    });
  }

  void _handleNotificationEvent(dynamic data) {
    try {
      _logger.i('Received notification event');
      if (data is Map<String, dynamic>) {
        final notification = NotificationModel.fromJson(data);
        _onNotification?.call(notification);
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing notification event',
          error: e, stackTrace: stackTrace);
    }
  }

  void _handleTaskUpdateEvent(dynamic data) {
    try {
      _logger.i('Received task update event: $data');
      final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
      for (final cb in _onTaskUpdateCallbacks) {
        cb(map);
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing task update event',
          error: e, stackTrace: stackTrace);
    }
  }

  void _handleApprovalUpdateEvent(dynamic data) {
    try {
      _logger.i('Received approval update event: $data');
      final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
      for (final cb in _onApprovalUpdateCallbacks) {
        cb(map);
      }
      // Approval events also affect tasks
      for (final cb in _onTaskUpdateCallbacks) {
        cb(map);
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing approval update event',
          error: e, stackTrace: stackTrace);
    }
  }

  void _handleUserUpdateEvent(dynamic data) {
    try {
      _logger.i('Received user update event: $data');
      final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
      for (final cb in _onUserUpdateCallbacks) {
        cb(map);
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing user update event',
          error: e, stackTrace: stackTrace);
    }
  }

  /// Subscribe to user's personal notification room
  void _subscribeToNotifications() {
    try {
      final userId = TokenService.instance.userId;
      if (userId != null && _socket != null) {
        _socket!.emit('subscribe', {'room': 'user:$userId'});
        _logger.i('Subscribed to user notifications for user:$userId');
      }
    } catch (e, stackTrace) {
      _logger.e('Error subscribing to notifications',
          error: e, stackTrace: stackTrace);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // CALLBACK REGISTRATION
  // ════════════════════════════════════════════════════════════════════════

  void onNotification(OnNotificationCallback callback) {
    _onNotification = callback;
  }

  void onNotificationUpdate(OnNotificationUpdateCallback callback) {
    _onNotificationUpdate = callback;
  }

  void onUnreadCountChange(OnUnreadCountCallback callback) {
    _onUnreadCountChange = callback;
  }

  /// Register a callback for task update events.
  /// Returns a dispose function to unregister.
  void Function() onTaskUpdate(OnDataChangeCallback callback) {
    _onTaskUpdateCallbacks.add(callback);
    return () => _onTaskUpdateCallbacks.remove(callback);
  }

  /// Register a callback for user update events.
  /// Returns a dispose function to unregister.
  void Function() onUserUpdate(OnDataChangeCallback callback) {
    _onUserUpdateCallbacks.add(callback);
    return () => _onUserUpdateCallbacks.remove(callback);
  }

  /// Register a callback for approval update events.
  /// Returns a dispose function to unregister.
  void Function() onApprovalUpdate(OnDataChangeCallback callback) {
    _onApprovalUpdateCallbacks.add(callback);
    return () => _onApprovalUpdateCallbacks.remove(callback);
  }

  // ════════════════════════════════════════════════════════════════════════
  // POLLING FALLBACK
  // ════════════════════════════════════════════════════════════════════════

  /// Register a callback that fires on each poll tick.
  /// The callback should call provider refresh methods.
  void onPollTick(VoidCallbackAsync callback) {
    _onPollTick = callback;
  }

  void _startPollingFallback() {
    if (_pollingActive) return;
    _pollingActive = true;
    _logger.i('Starting polling fallback (every 30s)');
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isConnected) {
        // Socket reconnected — stop polling
        _stopPollingFallback();
        return;
      }
      _logger.d('Polling tick');
      try {
        await _onPollTick?.call();
      } catch (e) {
        _logger.e('Polling tick error: $e');
      }
    });
  }

  void _stopPollingFallback() {
    if (!_pollingActive) return;
    _pollingActive = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _logger.i('Stopped polling fallback');
  }

  // ════════════════════════════════════════════════════════════════════════
  // EMIT / DISCONNECT / DISPOSE
  // ════════════════════════════════════════════════════════════════════════

  void emit(String event, [dynamic data]) {
    if (_isConnected && _socket != null) {
      _socket!.emit(event, data);
      _logger.d('Emitted socket event: $event');
    } else {
      _logger.w('Socket not connected, cannot emit event: $event');
    }
  }

  Future<void> disconnect() async {
    try {
      _stopPollingFallback();
      _socket?.disconnect();
      _isConnected = false;
      _isInitialized = false;
      _logger.i('Socket disconnected');
    } catch (e, stackTrace) {
      _logger.e('Error disconnecting socket',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> reconnect() async {
    if (_isConnected) {
      _logger.w('Socket already connected');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.e('Max reconnection attempts reached, falling back to polling');
      _startPollingFallback();
      return;
    }

    _reconnectAttempts++;
    final delay = _initialReconnectDelay * pow(2, _reconnectAttempts - 1).toInt();

    _logger.i('Attempting to reconnect (attempt $_reconnectAttempts), delay: ${delay}ms');

    await Future.delayed(Duration(milliseconds: delay));

    try {
      _socket?.connect();
    } catch (e, stackTrace) {
      _logger.e('Error reconnecting socket',
          error: e, stackTrace: stackTrace);
    }
  }

  void dispose() {
    try {
      disconnect();
      _onNotification = null;
      _onNotificationUpdate = null;
      _onUnreadCountChange = null;
      _onTaskUpdateCallbacks.clear();
      _onUserUpdateCallbacks.clear();
      _onApprovalUpdateCallbacks.clear();
      _onPollTick = null;
      _logger.i('Socket service disposed');
    } catch (e, stackTrace) {
      _logger.e('Error disposing socket service',
          error: e, stackTrace: stackTrace);
    }
  }
}

typedef VoidCallbackAsync = Future<void> Function();
