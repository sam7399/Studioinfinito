import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import 'attachment_section.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final int taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  TaskModel? _task;
  List<TaskActivity> _activities = [];
  bool _loading = true;
  bool _actionsLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final task = await ref.read(taskProvider.notifier).getTask(widget.taskId);
    final acts =
        await ref.read(taskProvider.notifier).getTaskActivities(widget.taskId);
    if (mounted) {
      setState(() {
        _task = task;
        _activities = acts;
        _loading = false;
        _error = task == null ? 'Task not found' : null;
      });
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    setState(() => _actionsLoading = true);
    final ok = await ref
        .read(taskProvider.notifier)
        .updateTask(widget.taskId, {'status': newStatus});
    if (mounted) {
      if (ok) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Status updated to ${newStatus.replaceAll("_", " ")}')));
        }
      } else {
        setState(() => _actionsLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Failed to update status'),
              backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showReviewDialog() {
    String reviewStatus = 'approved';
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Review Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Decision',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ReviewOption(
                      label: 'Approve',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      selected: reviewStatus == 'approved',
                      onTap: () => setS(() => reviewStatus = 'approved'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ReviewOption(
                      label: 'Reopen',
                      icon: Icons.refresh,
                      color: Colors.orange,
                      selected: reviewStatus == 'reopened',
                      onTap: () => setS(() => reviewStatus = 'reopened'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _actionsLoading = true);
                await ref.read(taskProvider.notifier).submitReview(
                    widget.taskId, {
                  'status': reviewStatus,
                  if (commentCtrl.text.isNotEmpty) 'comment': commentCtrl.text,
                });
                if (mounted) await _load();
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
            'Delete "${_task?.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(taskProvider.notifier)
                  .deleteTask(widget.taskId);
              if (mounted) context.go('/tasks');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(authProvider).user?.role ?? '';
    final isManagement =
        userRole == 'superadmin' || userRole == 'management';

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => context.go('/tasks'),
                child: const Text('Back to Tasks')),
          ]),
        ),
      );
    }

    final task = _task!;
    final daysLeft = task.dueDate != null
        ? task.dueDate!.difference(DateTime.now()).inDays
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                    onPressed: () => context.go('/tasks'),
                    icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(task.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                if (isManagement)
                  IconButton(
                    icon:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete task',
                    onPressed: _showDeleteDialog,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Info card ────────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _StatusBadge(task.status),
                      _PriorityBadge(task.priority),
                      if (task.isOverdue) _Chip('OVERDUE', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Info grid
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _InfoItem(Icons.person_outline, 'Assigned To',
                          task.assignedToName ?? '#${task.assignedTo}'),
                      _InfoItem(Icons.person_add_alt_1_outlined, 'Created By',
                          task.createdByName ?? '#${task.createdBy}'),
                      _InfoItem(Icons.account_tree_outlined, 'Department',
                          task.departmentName ?? '#${task.departmentId}'),
                      _InfoItem(Icons.location_on_outlined, 'Location',
                          task.locationName ?? '#${task.locationId}'),
                      if (task.dueDate != null)
                        _InfoItem(
                          Icons.calendar_today_outlined,
                          'Due Date',
                          '${DateFormat('MMM dd, yyyy').format(task.dueDate!.toLocal())}'
                              '${daysLeft != null ? (daysLeft < 0 ? ' (${-daysLeft}d overdue)' : daysLeft == 0 ? ' (today)' : ' (${daysLeft}d left)') : ''}',
                        ),
                      if (task.estimatedHours != null)
                        _InfoItem(Icons.schedule_outlined, 'Est. Hours',
                            '${task.estimatedHours!.toStringAsFixed(1)}h'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress bar
                  Row(
                    children: [
                      const Text('Progress',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      Text('${task.progressPercent}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progressPercent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      color: task.progressPercent == 100
                          ? Colors.green
                          : const Color(0xFF3B82F6),
                    ),
                  ),

                  // Description
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Description',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(task.description!,
                        style: TextStyle(
                            color: Colors.grey.shade700, height: 1.5)),
                  ],

                  // Tags
                  if (task.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: task.tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(t,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade700)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Attachments ───────────────────────────────────────────
            _Card(
              child: TaskAttachmentSection(
                taskId: widget.taskId,
                canUpload: true,
              ),
            ),
            const SizedBox(height: 16),

            // ── Action buttons ────────────────────────────────────────
            if (_actionsLoading)
              const Center(child: CircularProgressIndicator())
            else
              _ActionButtons(
                task: task,
                isManagement: isManagement,
                onChangeStatus: _changeStatus,
                onReview: _showReviewDialog,
              ),

            const SizedBox(height: 24),

            // ── Activity log ─────────────────────────────────────────
            Text('Activity Log',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ActivityLog(activities: _activities),
          ],
        ),
      ),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────
class _ActionButtons extends StatelessWidget {
  final TaskModel task;
  final bool isManagement;
  final void Function(String) onChangeStatus;
  final VoidCallback onReview;
  const _ActionButtons(
      {required this.task,
      required this.isManagement,
      required this.onChangeStatus,
      required this.onReview});

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    switch (task.status) {
      case 'open':
      case 'reopened':
        buttons.add(FilledButton.icon(
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Start Task'),
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6)),
          onPressed: () => onChangeStatus('in_progress'),
        ));
      case 'in_progress':
        buttons.add(FilledButton.icon(
          icon: const Icon(Icons.rate_review_outlined, size: 18),
          label: const Text('Submit for Review'),
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF97316)),
          onPressed: () => onChangeStatus('complete_pending_review'),
        ));
      case 'complete_pending_review':
        if (isManagement) {
          buttons.add(FilledButton.icon(
            icon: const Icon(Icons.star_outline, size: 18),
            label: const Text('Review Task'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981)),
            onPressed: onReview,
          ));
        }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 8, children: buttons);
  }
}

// ── Activity log ──────────────────────────────────────────────────────────────
class _ActivityLog extends StatelessWidget {
  final List<TaskActivity> activities;
  const _ActivityLog({required this.activities});

  IconData _icon(String action) => switch (action) {
        'created' => Icons.add_circle_outline,
        'updated' => Icons.edit_outlined,
        'assigned' => Icons.person_add_outlined,
        'completed' => Icons.check_circle_outline,
        'approved' => Icons.done_all,
        'reopened' => Icons.refresh,
        _ => Icons.circle_outlined,
      };

  Color _color(String action) => switch (action) {
        'created' => Colors.blue,
        'approved' => Colors.green,
        'reopened' => Colors.orange,
        'completed' => Colors.purple,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No activity recorded yet',
                style: TextStyle(color: Colors.grey.shade500)),
          ),
        ),
      );
    }

    return _Card(
      child: Column(
        children: activities.asMap().entries.map((e) {
          final i = e.key;
          final a = e.value;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _color(a.action).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon(a.action),
                        size: 15, color: _color(a.action)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a.actorName ?? 'User'} ${a.action} this task',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                        if (a.note != null && a.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(a.note!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic)),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM dd, yyyy HH:mm')
                              .format(a.createdAt.toLocal()),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < activities.length - 1) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  Color get _c => switch (status) {
        'finalized' => Colors.green,
        'in_progress' => const Color(0xFF8B5CF6),
        'complete_pending_review' => Colors.orange,
        'reopened' => Colors.red,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) =>
      _Chip(status.replaceAll('_', ' ').toUpperCase(), _c);
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge(this.priority);

  Color get _c => switch (priority) {
        'urgent' => Colors.red,
        'high' => Colors.orange,
        'normal' => Colors.blue,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) =>
      _Chip(priority.toUpperCase(), _c);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

class _ReviewOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ReviewOption(
      {required this.label,
      required this.icon,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          border: Border.all(
              color: selected ? color : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? color : Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
