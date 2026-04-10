import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/approval_provider.dart';

/// Widget displaying approval icon with pending count badge
class ApprovalBadge extends ConsumerWidget {
  final VoidCallback? onPressed;
  final Color? badgeColor;
  final Color? iconColor;
  final double iconSize;

  const ApprovalBadge({
    Key? key,
    this.onPressed,
    this.badgeColor,
    this.iconColor,
    this.iconSize = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(pendingApprovalsCountProvider);

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.approval_outlined,
            size: iconSize,
            color: iconColor ?? Colors.black87,
          ),
          onPressed: onPressed ?? () => context.push('/approvals'),
          tooltip: 'Task Approvals',
        ),
        countAsync.when(
          data: (count) {
            if (count == 0) return const SizedBox.shrink();
            return Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Menu item widget for approval navigation with count
class ApprovalNavItem extends ConsumerWidget {
  final String currentLocation;

  const ApprovalNavItem({
    Key? key,
    required this.currentLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(pendingApprovalsCountProvider);
    final isActive = currentLocation == '/approvals' || currentLocation.startsWith('/approvals/');

    return countAsync.when(
      data: (count) {
        return _buildNavItem(context, isActive, count);
      },
      loading: () => _buildNavItem(context, isActive, 0),
      error: (_, __) => _buildNavItem(context, isActive, 0),
    );
  }

  Widget _buildNavItem(BuildContext context, bool isActive, int count) {
    return InkWell(
      onTap: () => context.push('/approvals'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.approval_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Approvals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
