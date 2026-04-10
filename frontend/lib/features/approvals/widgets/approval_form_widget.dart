import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum ApprovalAction { approve, reject, none }

class ApprovalFormWidget extends StatefulWidget {
  final String taskTitle;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool isLoading;
  final String? errorMessage;
  final Function(String comments)? onApproveWithComments;
  final Function(String reason)? onRejectWithReason;

  const ApprovalFormWidget({
    super.key,
    required this.taskTitle,
    this.onApprove,
    this.onReject,
    this.isLoading = false,
    this.errorMessage,
    this.onApproveWithComments,
    this.onRejectWithReason,
  });

  @override
  State<ApprovalFormWidget> createState() => _ApprovalFormWidgetState();
}

class _ApprovalFormWidgetState extends State<ApprovalFormWidget> {
  final _commentController = TextEditingController();
  final _reasonController = TextEditingController();
  ApprovalAction _selectedAction = ApprovalAction.none;

  @override
  void dispose() {
    _commentController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _handleApprove() {
    if (widget.onApproveWithComments != null) {
      widget.onApproveWithComments!(_commentController.text);
    } else {
      widget.onApprove?.call();
    }
  }

  void _handleReject() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for rejection')),
      );
      return;
    }
    if (widget.onRejectWithReason != null) {
      widget.onRejectWithReason!(reason);
    } else {
      widget.onReject?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Review Task',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.taskTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),

            // Error message
            if (widget.errorMessage != null) ...[
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
                        widget.errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action selection
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Approve',
                    icon: Icons.check_circle_outline,
                    color: GemColors.green,
                    isSelected: _selectedAction == ApprovalAction.approve,
                    onPressed: () {
                      setState(() => _selectedAction = ApprovalAction.approve);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Reject',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFEF4444),
                    isSelected: _selectedAction == ApprovalAction.reject,
                    onPressed: () {
                      setState(() => _selectedAction = ApprovalAction.reject);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content based on selected action
            if (_selectedAction != ApprovalAction.none) ...[
              if (_selectedAction == ApprovalAction.approve) ...[
                _buildApproveSection(),
              ] else if (_selectedAction == ApprovalAction.reject) ...[
                _buildRejectSection(),
              ],
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApproveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add approval comments (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Share your thoughts about the completed task...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for rejection *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reasonController,
          maxLines: 4,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Explain why the task needs to be reworked...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The task will be returned to the assignee with your feedback.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: widget.isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: widget.isLoading
                ? null
                : (_selectedAction == ApprovalAction.approve
                    ? _handleApprove
                    : _handleReject),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedAction == ApprovalAction.approve
                  ? GemColors.green
                  : const Color(0xFFEF4444),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(_selectedAction == ApprovalAction.approve
                    ? 'Approve Task'
                    : 'Reject Task'),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
