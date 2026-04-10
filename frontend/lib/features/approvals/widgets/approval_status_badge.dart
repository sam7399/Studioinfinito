import 'package:flutter/material.dart';
import '../models/approval_model.dart';

class ApprovalStatusBadge extends StatelessWidget {
  final String? approvalStatus;
  final bool compact;
  final double fontSize;

  const ApprovalStatusBadge({
    super.key,
    required this.approvalStatus,
    this.compact = false,
    this.fontSize = 12,
  });

  Color _getStatusColor() {
    switch (approvalStatus?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (approvalStatus?.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel() {
    switch (approvalStatus?.toLowerCase()) {
      case 'pending':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (approvalStatus == null) {
      return const SizedBox.shrink();
    }

    final color = _getStatusColor();

    if (compact) {
      return Chip(
        avatar: Icon(_getStatusIcon(), size: 16, color: color),
        label: Text(
          _getStatusLabel(),
          style: TextStyle(
            fontSize: fontSize - 2,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color.withOpacity(0.1),
        side: BorderSide(color: color.withOpacity(0.3)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            _getStatusLabel(),
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to show approval status for tasks in a compact form
class TaskApprovalStatusWidget extends StatelessWidget {
  final String? approvalStatus;
  final String? statusLabel;

  const TaskApprovalStatusWidget({
    super.key,
    required this.approvalStatus,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (approvalStatus == null || approvalStatus == 'null') {
      return const SizedBox.shrink();
    }

    return ApprovalStatusBadge(
      approvalStatus: approvalStatus,
      compact: true,
      fontSize: 11,
    );
  }
}
