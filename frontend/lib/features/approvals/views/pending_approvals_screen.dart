import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/approval_provider.dart';
import '../widgets/approval_card.dart';
import '../../../core/theme/app_theme.dart';

class PendingApprovalsScreen extends ConsumerWidget {
  const PendingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsState = ref.watch(pendingApprovalsProvider);
    final isLoading = approvalsState.isLoading;
    final error = approvalsState.error;
    final approvals = approvalsState.approvals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Approvals'),
        backgroundColor: GemColors.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!isLoading && approvals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '${approvals.length}/${approvalsState.total}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pendingApprovalsProvider.notifier).refreshPendingApprovals(),
        child: _buildBody(context, ref, isLoading, error, approvals, approvalsState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    bool isLoading,
    String? error,
    List approvals,
    PendingApprovalsState state,
  ) {
    // Loading state
    if (isLoading && approvals.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Error state
    if (error != null && approvals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load approvals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  ref.read(pendingApprovalsProvider.notifier).refreshPendingApprovals(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (approvals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: GemColors.green.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'No tasks are pending your approval',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => context.push('/tasks'),
              child: const Text('View All Tasks'),
            ),
          ],
        ),
      );
    }

    // List with pagination
    return ListView.builder(
      itemCount: approvals.length + (state.hasNextPage ? 1 : 0),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        if (index == approvals.length && state.hasNextPage) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: ElevatedButton(
                onPressed: () => ref.read(pendingApprovalsProvider.notifier).nextPage(),
                child: const Text('Load More'),
              ),
            ),
          );
        }

        final approval = approvals[index];
        final isMobile = MediaQuery.of(context).size.width < 600;

        return ApprovalCard(
          approval: approval,
          onTap: () => context.push('/approvals/${approval.task.id}'),
          onApprove: isMobile
              ? null
              : () => _showApprovalDialog(context, ref, approval.task.id, approval.task.title),
          onReject: isMobile
              ? null
              : () => _showRejectionDialog(context, ref, approval.task.id, approval.task.title),
        );
      },
    );
  }

  void _showApprovalDialog(BuildContext context, WidgetRef ref, int taskId, String taskTitle) {
    showDialog(
      context: context,
      builder: (_) => _ApprovalDialog(
        taskId: taskId,
        taskTitle: taskTitle,
        ref: ref,
      ),
    );
  }

  void _showRejectionDialog(BuildContext context, WidgetRef ref, int taskId, String taskTitle) {
    showDialog(
      context: context,
      builder: (_) => _RejectionDialog(
        taskId: taskId,
        taskTitle: taskTitle,
        ref: ref,
      ),
    );
  }
}

class _ApprovalDialog extends ConsumerStatefulWidget {
  final int taskId;
  final String taskTitle;
  final WidgetRef ref;

  const _ApprovalDialog({
    required this.taskId,
    required this.taskTitle,
    required this.ref,
  });

  @override
  ConsumerState<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends ConsumerState<_ApprovalDialog> {
  late TextEditingController _commentsController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _commentsController = TextEditingController();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  void _handleApprove() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref
          .read(pendingApprovalsProvider.notifier)
          .approveTask(widget.taskId, comments: _commentsController.text);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task approved successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.taskTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Comments (optional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentsController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Add your approval comments...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleApprove,
          style: ElevatedButton.styleFrom(
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
      ],
    );
  }
}

class _RejectionDialog extends ConsumerStatefulWidget {
  final int taskId;
  final String taskTitle;
  final WidgetRef ref;

  const _RejectionDialog({
    required this.taskId,
    required this.taskTitle,
    required this.ref,
  });

  @override
  ConsumerState<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends ConsumerState<_RejectionDialog> {
  late TextEditingController _reasonController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _handleReject() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please provide a reason for rejection');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref
          .read(pendingApprovalsProvider.notifier)
          .rejectTask(widget.taskId, reason);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task rejected and returned for rework')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.taskTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Rejection Reason *',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Explain why this task needs to be reworked...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The task will be returned to in_progress status.',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleReject,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
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
              : const Text('Reject'),
        ),
      ],
    );
  }
}
