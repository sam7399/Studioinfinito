import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';

/// Widget displaying notification bell icon with unread count badge
class NotificationBell extends ConsumerWidget {
  final VoidCallback onPressed;
  final Color? badgeColor;
  final Color? iconColor;
  final double iconSize;

  const NotificationBell({
    Key? key,
    required this.onPressed,
    this.badgeColor,
    this.iconColor,
    this.iconSize = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            size: iconSize,
            color: iconColor ?? Colors.black87,
          ),
          onPressed: onPressed,
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
