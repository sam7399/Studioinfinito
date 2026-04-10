import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/approval_model.dart';
import '../../../core/theme/app_theme.dart';

class ApprovalCard extends StatelessWidget {
  final PendingApprovalModel approval;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const ApprovalCard({
    super.key,
    required this.approval,
    required this.onTap,
    this.onApprove,
    this.onReject,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'normal':
        return const Color(0xFF3B82F6);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return GemColors.blue;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return DateFormat('hh:mm a').format(date);
    } else if (dateToCheck == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Duration _getAgeDuration() {
    return DateTime.now().difference(approval.approval.submittedAt);
  }

  String _getAgeDisplay() {
    final duration = _getAgeDuration();
    if (duration.inHours < 1) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ago';
    } else if (duration.inDays < 7) {
      return '${duration.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(approval.approval.submittedAt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = approval.task;
    final approval_ = approval.approval;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Priority badge, Title, Age
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(task.priority).withOpacity(0.1),
                      border: Border.all(
                        color: _getPriorityColor(task.priority).withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(task.priority),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Submitted ${_getAgeDisplay()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Creator and Assignee info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      icon: Icons.person_outline,
                      label: 'Created by',
                      value: task.createdByName ?? 'Unknown',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.assignment_ind_outlined,
                      label: 'Assigned to',
                      value: task.assignedToName ?? 'Unassigned',
                    ),
                    if (task.dueDate != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Due date',
                        value: DateFormat('MMM d, yyyy').format(task.dueDate!),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons
              if (!isMobile && (onApprove != null || onReject != null))
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onReject != null)
                      SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                    if (onApprove != null && onReject != null) const SizedBox(width: 8),
                    if (onApprove != null)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GemColors.green,
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
