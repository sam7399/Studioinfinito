import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

/// Screen displaying detailed view of a single notification
class NotificationDetailScreen extends ConsumerStatefulWidget {
  final int notificationId;

  const NotificationDetailScreen({
    Key? key,
    required this.notificationId,
  }) : super(key: key);

  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen> {
  NotificationModel? _notification;

  @override
  void initState() {
    super.initState();
    _loadNotification();
  }

  void _loadNotification() {
    final notificationState = ref.read(notificationListProvider);
    _notification = notificationState.notifications
        .where((n) => n.id == widget.notificationId)
        .firstOrNull;

    // Mark as read if not already
    if (_notification != null && !_notification!.read) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(notificationListProvider.notifier)
            .markAsRead(widget.notificationId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationListProvider);
    final notification = notificationState.notifications
        .where((n) => n.id == widget.notificationId)
        .firstOrNull;

    if (notification == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification')),
        body: const Center(
          child: Text('Notification not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Details'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog(notification);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
            Container(
              color: Color(notification.colorCode).withOpacity(0.1),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(notification.colorCode).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        notification.iconData,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Color(notification.colorCode).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getTypeLabel(notification.type),
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(notification.colorCode),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    notification.description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Metadata if available
                  if (notification.metadata != null &&
                      notification.metadata!.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Additional Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._buildMetadataItems(notification.metadata!),
                  ],
                  const SizedBox(height: 24),
                  // Timestamp info
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Received',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, yyyy • HH:mm')
                                .format(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (notification.read && notification.readAt != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Read',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, yyyy • HH:mm')
                                  .format(notification.readAt!),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  if (notification.taskId != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.pop();
                          context.push('/tasks/${notification.taskId}');
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View Related Task'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMetadataItems(Map<String, dynamic> metadata) {
    return metadata.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              _formatMetadataKey(entry.key),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const Spacer(),
            Text(
              entry.value.toString(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatMetadataKey(String key) {
    return key
        .replaceAll(RegExp(r'([A-Z])'), ' \$1')
        .trim()
        .replaceFirst(key[0], key[0].toUpperCase());
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'task_assigned':
        return 'Task Assigned';
      case 'task_completed':
        return 'Task Completed';
      case 'task_status_changed':
        return 'Status Changed';
      case 'approval_pending':
      case 'task_approval_pending':
        return 'Approval Pending';
      case 'task_approval_approved':
        return 'Approved';
      case 'task_approval_rejected':
        return 'Rejected';
      case 'comment_added':
        return 'Comment Added';
      case 'deadline_approaching':
        return 'Deadline Approaching';
      default:
        return 'Notification';
    }
  }

  void _showDeleteDialog(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(notificationListProvider.notifier)
                  .deleteNotification(notification.id);
              Navigator.pop(context);
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
