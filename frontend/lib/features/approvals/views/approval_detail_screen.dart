import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/approval_model.dart';
import '../providers/approval_provider.dart';
import '../widgets/approval_form_widget.dart';
import '../widgets/approval_history_list.dart';
import '../../../core/theme/app_theme.dart';

class ApprovalDetailScreen extends ConsumerWidget {
  final int taskId;

  const ApprovalDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsState = ref.watch(pendingApprovalsProvider);
    final historyAsync = ref.watch(approvalHistoryProvider(taskId));

    // Find the approval in the list
    PendingApprovalModel? approval;
    try {
      approval = approvalsState.approvals.firstWhere((a) => a.task.id == taskId);
    } catch (e) {
      // Not found
    }

    if (approval == null && approvalsState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (approval == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Task Details'),
          backgroundColor: GemColors.darkSurface,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Task not found'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final task = approval.task;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Task'),
        backgroundColor: GemColors.darkSurface,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task header
            Container(
              color: Colors.grey.withOpacity(0.05),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (task.description != null && task.description!.isNotEmpty)
                    Text(
                      task.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                ],
              ),
            ),

            // Task details
            _buildDetailSection(
              'Task Details',
              [
                _buildDetailRow('Status', task.status),
                _buildDetailRow('Created by', task.createdByName ?? 'Unknown'),
                _buildDetailRow('Assigned to', task.assignedToName ?? 'Unassigned'),
                _buildDetailRow('Department', task.departmentName ?? 'Unknown'),
                if (task.dueDate != null)
                  _buildDetailRow(
                    'Due date',
                    DateFormat('MMM d, yyyy').format(task.dueDate!),
                  ),
                if (task.estimatedHours != null)
                  _buildDetailRow('Estimated hours', '${task.estimatedHours}h'),
                _buildDetailRow('Progress', '${task.progressPercent}%'),
              ],
            ),

            // Approval details
            _buildDetailSection(
              'Approval Information',
              [
                _buildDetailRow('Submitted', DateFormat('MMM d, yyyy • h:mm a').format(approval.approval.submittedAt)),
                _buildDetailRow('Approver', approval.approval.approver?.name ?? 'Pending'),
                _buildDetailRow('Status', approval.approval.status.toUpperCase()),
              ],
            ),

            // Approval history
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Approval History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  historyAsync.when(
                    data: (history) => ApprovalHistoryList(history: history),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => ApprovalHistoryList(
                      history: [],
                      error: err.toString(),
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            if (approval.approval.status == 'pending')
              Padding(
                padding: const EdgeInsets.all(16),
                child: _ApprovalActionsWidget(
                  taskId: taskId,
                  taskTitle: task.title,
                  ref: ref,
                  onSuccess: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Action completed')),
                    );
                    context.pop();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: List.generate(
                children.length,
                (index) => Column(
                  children: [
                    children[index],
                    if (index < children.length - 1)
                      Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

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
}

class _ApprovalActionsWidget extends ConsumerStatefulWidget {
  final int taskId;
  final String taskTitle;
  final WidgetRef ref;
  final VoidCallback onSuccess;

  const _ApprovalActionsWidget({
    required this.taskId,
    required this.taskTitle,
    required this.ref,
    required this.onSuccess,
  });

  @override
  ConsumerState<_ApprovalActionsWidget> createState() => _ApprovalActionsWidgetState();
}

class _ApprovalActionsWidgetState extends ConsumerState<_ApprovalActionsWidget> {
  bool _isLoading = false;
  String? _error;

  void _handleApprove(String comments) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref
          .read(pendingApprovalsProvider.notifier)
          .approveTask(widget.taskId, comments: comments);
      widget.onSuccess();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _handleReject(String reason) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(pendingApprovalsProvider.notifier).rejectTask(widget.taskId, reason);
      widget.onSuccess();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => ApprovalFormWidget(
                            taskTitle: widget.taskTitle,
                            isLoading: _isLoading,
                            errorMessage: _error,
                            onRejectWithReason: _handleReject,
                          ),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  foregroundColor: const Color(0xFFEF4444),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => ApprovalFormWidget(
                            taskTitle: widget.taskTitle,
                            isLoading: _isLoading,
                            errorMessage: _error,
                            onApproveWithComments: _handleApprove,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: GemColors.green,
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
                    : const Text('Approve'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
