import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notification_provider.dart';
import '../widgets/notification_card.dart';
import '../widgets/empty_notification_state.dart';

/// Screen displaying paginated list of all notifications
class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends ConsumerState<NotificationListScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    // Load notifications on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(notificationListProvider.notifier)
          .fetchNotifications(page: 1, filter: _selectedFilter);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
        actions: [
          if (notificationState.unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
                await ref
                    .read(notificationListProvider.notifier)
                    .markAllAsRead();
              },
              icon: const Icon(Icons.done_all),
              label: const Text('Mark All Read'),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete-read') {
                _showDeleteReadDialog();
              } else if (value == 'settings') {
                context.push('/notifications/settings');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'delete-read',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 12),
                    Text('Delete Read'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18),
                    SizedBox(width: 12),
                    Text('Notification Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('unread', 'Unread'),
                  const SizedBox(width: 8),
                  _buildFilterChip('read', 'Read'),
                ],
              ),
            ),
          ),
          // Notifications list
          Expanded(
            child: notificationState.isLoading && notificationState.notifications.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : notificationState.notifications.isEmpty
                    ? EmptyNotificationState(
                        onRefresh: () => ref
                            .read(notificationListProvider.notifier)
                            .fetchNotifications(
                              page: 1,
                              filter: _selectedFilter,
                            ),
                      )
                    : ListView.builder(
                        itemCount: notificationState.notifications.length + 1,
                        itemBuilder: (context, index) {
                          // Last item is pagination controls
                          if (index == notificationState.notifications.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (notificationState.hasPreviousPage)
                                    ElevatedButton(
                                      onPressed: () => ref
                                          .read(notificationListProvider.notifier)
                                          .loadPreviousPage(),
                                      child: const Text('← Previous'),
                                    ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Page ${notificationState.currentPage} of ${notificationState.totalPages}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(width: 16),
                                  if (notificationState.hasNextPage)
                                    ElevatedButton(
                                      onPressed: () => ref
                                          .read(notificationListProvider.notifier)
                                          .loadNextPage(),
                                      child: const Text('Next →'),
                                    ),
                                ],
                              ),
                            );
                          }

                          final notification =
                              notificationState.notifications[index];

                          return NotificationCard(
                            notification: notification,
                            onTap: () {
                              context.push(
                                '/notifications/${notification.id}',
                              );
                            },
                            onMarkRead: () {
                              ref
                                  .read(notificationListProvider.notifier)
                                  .markAsRead(notification.id);
                            },
                            onDelete: () {
                              ref
                                  .read(notificationListProvider.notifier)
                                  .deleteNotification(notification.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notification deleted'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            onNavigate: () {
                              if (notification.taskId != null) {
                                context.push('/tasks/${notification.taskId}');
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        ref.read(notificationListProvider.notifier).fetchNotifications(
              page: 1,
              filter: value,
            );
      },
      selectedColor: Colors.blue.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  void _showDeleteReadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Read Notifications?'),
        content: const Text(
          'This action cannot be undone. All read notifications will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(notificationListProvider.notifier)
                  .deleteReadNotifications();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Read notifications deleted'),
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
