import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  final _searchCtrl = TextEditingController();
  String? _statusFilter;
  String? _priorityFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(taskProvider.notifier).fetchTasks(
      filters: {
        if (_searchCtrl.text.isNotEmpty) 'search': _searchCtrl.text,
        if (_statusFilter != null) 'status': _statusFilter,
        if (_priorityFilter != null) 'priority': _priorityFilter,
      },
      reset: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tasks', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${state.tasks.length} tasks loaded', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/tasks/create-multi'),
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('Create Multiple'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => context.go('/tasks/create'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Task'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                _FilterDropdown(
                  value: _statusFilter,
                  hint: 'All Status',
                  items: const {
                    'open': 'Open',
                    'in_progress': 'In Progress',
                    'complete_pending_review': 'Pending Review',
                    'finalized': 'Finalized',
                    'reopened': 'Reopened',
                  },
                  onChanged: (v) { setState(() => _statusFilter = v); _applyFilters(); },
                ),
                _FilterDropdown(
                  value: _priorityFilter,
                  hint: 'All Priority',
                  items: const {'low': 'Low', 'normal': 'Normal', 'high': 'High', 'urgent': 'Urgent'},
                  onChanged: (v) { setState(() => _priorityFilter = v); _applyFilters(); },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    setState(() { _statusFilter = null; _priorityFilter = null; _searchCtrl.clear(); });
                    ref.read(taskProvider.notifier).fetchTasks(reset: true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Builder(builder: (_) {
                if (state.isLoading && state.tasks.isEmpty) return const Center(child: CircularProgressIndicator());
                if (state.error != null && state.tasks.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(state.error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () => ref.read(taskProvider.notifier).fetchTasks(reset: true), child: const Text('Retry')),
                    ]),
                  );
                }
                if (state.tasks.isEmpty) {
                  return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No tasks found.'),
                  ]));
                }
                return ListView.builder(
                  itemCount: state.tasks.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == state.tasks.length) {
                      ref.read(taskProvider.notifier).fetchTasks();
                      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                    }
                    return _TaskCard(task: state.tasks[i]);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({required this.value, required this.hint, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          items: [
            DropdownMenuItem(value: null, child: Text(hint, style: const TextStyle(fontSize: 13))),
            ...items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  const _TaskCard({required this.task});

  Color _priorityColor(String p) => switch (p) {
        'urgent' => Colors.red,
        'high' => Colors.orange,
        'normal' => Colors.blue,
        _ => Colors.grey,
      };

  Color _statusColor(String s) => switch (s) {
        'finalized' => Colors.green,
        'in_progress' => Colors.blue,
        'complete_pending_review' => Colors.orange,
        'reopened' => Colors.red,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;
    final restricted = task.isRestricted;

    Border? cardBorder;
    if (restricted) {
      cardBorder = Border.all(color: Colors.blueGrey.shade100);
    } else if (isOverdue) {
      cardBorder = Border.all(color: Colors.red.shade200);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: restricted ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        border: cardBorder,
      ),
      child: InkWell(
        onTap: () => context.go('/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: restricted ? Colors.blueGrey.shade200 : _priorityColor(task.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (restricted) ...[
                          Icon(Icons.lock_outline, size: 13, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: restricted ? Colors.blueGrey.shade600 : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOverdue && !restricted) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Text('OVERDUE', style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (restricted)
                      Row(children: [
                        Icon(Icons.lock_outline, size: 11, color: Colors.blueGrey.shade400),
                        const SizedBox(width: 4),
                        Text('Cross-dept · restricted', style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade400, fontStyle: FontStyle.italic)),
                        const Spacer(),
                        if (task.dueDate != null) ...[
                          Icon(Icons.flag_outlined, size: 12, color: Colors.blueGrey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(task.dueDate!.toLocal()),
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ])
                    else
                      Row(
                        children: [
                          _Badge(label: task.status.replaceAll('_', ' '), color: _statusColor(task.status)),
                          const SizedBox(width: 6),
                          _Badge(label: task.priority, color: _priorityColor(task.priority)),
                          if (task.escalationLevel > 0) ...[
                            const SizedBox(width: 6),
                            _EscalationBadge(level: task.escalationLevel),
                          ],
                          if (task.assignedToName != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.person_outline, size: 11, color: Colors.grey.shade500),
                            const SizedBox(width: 2),
                            Text(task.assignedToName!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                          if (task.collaboratorNames.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.people_outline, size: 11, color: Colors.indigo.shade300),
                            const SizedBox(width: 2),
                            Text(
                              '+${task.collaboratorNames.length}',
                              style: TextStyle(fontSize: 11, color: Colors.indigo.shade400, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const Spacer(),
                          Icon(Icons.calendar_today_outlined, size: 12, color: isOverdue ? Colors.red : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            task.dueDate != null
                                ? DateFormat('MMM dd, yyyy').format(task.dueDate!.toLocal())
                                : 'No due date',
                            style: TextStyle(fontSize: 12, color: isOverdue ? Colors.red : Colors.grey.shade600),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: restricted ? Colors.blueGrey.shade300 : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _EscalationBadge extends StatelessWidget {
  final int level;
  const _EscalationBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      1 => ('ESC L1', Colors.orange),
      2 => ('ESC L2', Colors.deepOrange),
      _ => ('CRITICAL', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warning_amber_rounded, size: 9, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
