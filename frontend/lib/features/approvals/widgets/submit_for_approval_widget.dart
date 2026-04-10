import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/approval_model.dart';
import '../providers/approval_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Widget to show submit for approval button and status for tasks
class SubmitForApprovalWidget extends ConsumerStatefulWidget {
  final int taskId;
  final String taskTitle;
  final String taskStatus;
  final String? approvalStatus;
  final VoidCallback onSuccess;

  const SubmitForApprovalWidget({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.taskStatus,
    this.approvalStatus,
    required this.onSuccess,
  });

  @override
  ConsumerState<SubmitForApprovalWidget> createState() =>
      _SubmitForApprovalWidgetState();
}

class _SubmitForApprovalWidgetState extends ConsumerState<SubmitForApprovalWidget> {
  bool _isLoading = false;
  String? _error;

  /// Check if this task can be submitted for approval
  bool get canSubmitForApproval {
    // Task should be in 'complete_pending_review' status (or 'finalized' but not yet submitted)
    return widget.taskStatus == 'complete_pending_review' ||
        (widget.taskStatus == 'finalized' && widget.approvalStatus == null);
  }

  /// Get the approval status display
  String get approvalStatusDisplay {
    if (widget.approvalStatus == null) return '';
    switch (widget.approvalStatus?.toLowerCase()) {
      case 'pending':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected - Awaiting Rework';
      default:
        return widget.approvalStatus ?? '';
    }
  }

  Color get approvalStatusColor {
    switch (widget.approvalStatus?.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return GemColors.green;
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  void _handleSubmitForApproval() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ref.read(submitTaskForApprovalProvider(widget.taskId).future);
      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task submitted for approval')),
          );
          widget.onSuccess();
        }
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showSubmissionDialog() {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit for Approval'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.taskTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add notes before submission (optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Any final notes or context for the approver...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your manager will review and approve or reject this task.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.pop(ctx);
                    _handleSubmitForApproval();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.blue,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text('Submit for Approval'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show nothing if task is not in approval-related status
    if (!canSubmitForApproval && widget.approvalStatus == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Show approval status if exists
        if (widget.approvalStatus != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: approvalStatusColor.withOpacity(0.1),
              border: Border.all(color: approvalStatusColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(widget.approvalStatus),
                  color: approvalStatusColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Approval Status',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        approvalStatusDisplay,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: approvalStatusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Show error if submission failed
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Show submit button if task can be submitted
        if (canSubmitForApproval)
          ElevatedButton(
            onPressed: _isLoading ? null : _showSubmissionDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: GemColors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text('Submit for Approval'),
          ),
      ],
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
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
}

/// Show approval status badge for a task
class TaskApprovalStatusWidget extends StatelessWidget {
  final String? approvalStatus;
  final String? rejectionReason;

  const TaskApprovalStatusWidget({
    super.key,
    this.approvalStatus,
    this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    if (approvalStatus == null) {
      return const SizedBox.shrink();
    }

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (approvalStatus?.toLowerCase()) {
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending Approval';
        break;
      case 'approved':
        statusColor = GemColors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (rejectionReason != null && rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rejectionReason!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
