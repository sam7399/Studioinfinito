/// Enum for notification types
enum NotificationType {
  taskAssigned,
  taskCompleted,
  taskStatusChanged,
  approvalPending,
  taskApprovalPending,
  taskApprovalApproved,
  taskApprovalRejected,
  commentAdded,
  deadlineApproaching,
  unknown,
}

/// Model for a notification
class NotificationModel {
  final int id;
  final int userId;
  final int? taskId;
  final String type;
  final String title;
  final String description;
  final Map<String, dynamic>? metadata;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    required this.userId,
    this.taskId,
    required this.type,
    required this.title,
    required this.description,
    this.metadata,
    required this.read,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the notification type enum
  NotificationType get notificationType {
    switch (type) {
      case 'task_assigned':
        return NotificationType.taskAssigned;
      case 'task_completed':
        return NotificationType.taskCompleted;
      case 'task_status_changed':
        return NotificationType.taskStatusChanged;
      case 'approval_pending':
        return NotificationType.approvalPending;
      case 'task_approval_pending':
        return NotificationType.taskApprovalPending;
      case 'task_approval_approved':
        return NotificationType.taskApprovalApproved;
      case 'task_approval_rejected':
        return NotificationType.taskApprovalRejected;
      case 'comment_added':
        return NotificationType.commentAdded;
      case 'deadline_approaching':
        return NotificationType.deadlineApproaching;
      default:
        return NotificationType.unknown;
    }
  }

  /// Get icon for notification type
  String get iconData {
    switch (notificationType) {
      case NotificationType.taskAssigned:
        return '📋';
      case NotificationType.taskCompleted:
        return '✅';
      case NotificationType.taskStatusChanged:
        return '🔄';
      case NotificationType.approvalPending:
      case NotificationType.taskApprovalPending:
        return '⏳';
      case NotificationType.taskApprovalApproved:
        return '✔️';
      case NotificationType.taskApprovalRejected:
        return '❌';
      case NotificationType.commentAdded:
        return '💬';
      case NotificationType.deadlineApproaching:
        return '⏰';
      default:
        return '🔔';
    }
  }

  /// Get color code for notification type
  int get colorCode {
    switch (notificationType) {
      case NotificationType.taskAssigned:
        return 0xFF2196F3;
      case NotificationType.taskCompleted:
        return 0xFF4CAF50;
      case NotificationType.taskStatusChanged:
        return 0xFF2196F3;
      case NotificationType.approvalPending:
      case NotificationType.taskApprovalPending:
        return 0xFFFFC107;
      case NotificationType.taskApprovalApproved:
        return 0xFF4CAF50;
      case NotificationType.taskApprovalRejected:
        return 0xFFF44336;
      case NotificationType.commentAdded:
        return 0xFF9C27B0;
      case NotificationType.deadlineApproaching:
        return 0xFFFF5722;
      default:
        return 0xFF757575;
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? json['userId'] as int? ?? 0,
      taskId: json['task_id'] as int? ?? json['taskId'] as int?,
      type: json['type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : json['readAt'] != null
              ? DateTime.tryParse(json['readAt'].toString())
              : null,
      createdAt: DateTime.parse(
          json['created_at']?.toString() ?? json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'task_id': taskId,
        'type': type,
        'title': title,
        'description': description,
        'metadata': metadata,
        'read': read,
        'read_at': readAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  NotificationModel copyWith({
    int? id,
    int? userId,
    int? taskId,
    String? type,
    String? title,
    String? description,
    Map<String, dynamic>? metadata,
    bool? read,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model for notification preferences
class NotificationPreferenceModel {
  final int id;
  final int userId;
  final bool taskAssigned;
  final bool taskCompleted;
  final bool taskCommented;
  final bool taskDeadlineApproaching;
  final bool taskStatusChanged;
  final bool taskReviewPending;
  final bool taskReviewApproved;
  final bool taskReviewRejected;
  final bool emailNotifications;
  final bool pushNotifications;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationPreferenceModel({
    required this.id,
    required this.userId,
    required this.taskAssigned,
    required this.taskCompleted,
    required this.taskCommented,
    required this.taskDeadlineApproaching,
    required this.taskStatusChanged,
    required this.taskReviewPending,
    required this.taskReviewApproved,
    required this.taskReviewRejected,
    required this.emailNotifications,
    required this.pushNotifications,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? json['userId'] as int? ?? 0,
      taskAssigned: json['task_assigned'] as bool? ?? json['taskAssigned'] as bool? ?? true,
      taskCompleted: json['task_completed'] as bool? ?? json['taskCompleted'] as bool? ?? true,
      taskCommented: json['task_commented'] as bool? ?? json['taskCommented'] as bool? ?? true,
      taskDeadlineApproaching: json['task_deadline_approaching'] as bool? ?? json['taskDeadlineApproaching'] as bool? ?? true,
      taskStatusChanged: json['task_status_changed'] as bool? ?? json['taskStatusChanged'] as bool? ?? true,
      taskReviewPending: json['task_review_pending'] as bool? ?? json['taskReviewPending'] as bool? ?? true,
      taskReviewApproved: json['task_review_approved'] as bool? ?? json['taskReviewApproved'] as bool? ?? true,
      taskReviewRejected: json['task_review_rejected'] as bool? ?? json['taskReviewRejected'] as bool? ?? true,
      emailNotifications: json['email_notifications'] as bool? ?? json['emailNotifications'] as bool? ?? true,
      pushNotifications: json['push_notifications'] as bool? ?? json['pushNotifications'] as bool? ?? true,
      createdAt: DateTime.parse(
          json['created_at']?.toString() ?? json['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'task_assigned': taskAssigned,
        'task_completed': taskCompleted,
        'task_commented': taskCommented,
        'task_deadline_approaching': taskDeadlineApproaching,
        'task_status_changed': taskStatusChanged,
        'task_review_pending': taskReviewPending,
        'task_review_approved': taskReviewApproved,
        'task_review_rejected': taskReviewRejected,
        'email_notifications': emailNotifications,
        'push_notifications': pushNotifications,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  NotificationPreferenceModel copyWith({
    int? id,
    int? userId,
    bool? taskAssigned,
    bool? taskCompleted,
    bool? taskCommented,
    bool? taskDeadlineApproaching,
    bool? taskStatusChanged,
    bool? taskReviewPending,
    bool? taskReviewApproved,
    bool? taskReviewRejected,
    bool? emailNotifications,
    bool? pushNotifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreferenceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskAssigned: taskAssigned ?? this.taskAssigned,
      taskCompleted: taskCompleted ?? this.taskCompleted,
      taskCommented: taskCommented ?? this.taskCommented,
      taskDeadlineApproaching: taskDeadlineApproaching ?? this.taskDeadlineApproaching,
      taskStatusChanged: taskStatusChanged ?? this.taskStatusChanged,
      taskReviewPending: taskReviewPending ?? this.taskReviewPending,
      taskReviewApproved: taskReviewApproved ?? this.taskReviewApproved,
      taskReviewRejected: taskReviewRejected ?? this.taskReviewRejected,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
