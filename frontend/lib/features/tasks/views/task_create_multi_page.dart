import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/dio_client.dart';
import '../../org/providers/org_provider.dart';

// ── Workload provider ─────────────────────────────────────────────────────────
// userId → (open + in_progress) count

final _workloadProvider =
    FutureProvider.autoDispose<Map<int, int>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final res = await dio.get(ApiConstants.reportSummary);
    final List byUser = res.data['data']['byUser'] ?? [];
    final map = <int, int>{};
    for (final row in byUser) {
      final uid = (row['assignee'] as Map?)?['id'] as int?;
      if (uid != null) {
        map[uid] = ((row['open'] as num?)?.toInt() ?? 0) +
            ((row['in_progress'] as num?)?.toInt() ?? 0);
      }
    }
    return map;
  } catch (_) {
    return {};
  }
});

// ── Row data ──────────────────────────────────────────────────────────────────

class _RowData {
  /// Multiple users — one task is created per user when saved.
  List<int> assignedUserIds = [];

  int? locationId;
  String priority = 'high';
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final DateTime assignDate = DateTime.now();
  DateTime? dueDate;

  /// When true, all tasks spawned from this row are tagged with a shared
  /// group ID so they are traceable as "linked" in the task list.
  bool linkTasks = false;

  bool get isValid =>
      assignedUserIds.isNotEmpty &&
      locationId != null &&
      titleCtrl.text.trim().isNotEmpty &&
      dueDate != null;

  /// How many individual tasks this row will produce when saved.
  int get taskCount =>
      assignedUserIds.isEmpty ? 0 : assignedUserIds.length;

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
  }
}

// ── Colour helpers ────────────────────────────────────────────────────────────

const _orange = Color(0xFFE65C00);
const _slate = Color(0xFF334155);

Color _wColor(int n) {
  if (n <= 3) return const Color(0xFF16A34A);
  if (n <= 6) return const Color(0xFFD97706);
  return const Color(0xFFDC2626);
}

String _wLabel(int n) {
  if (n == 0) return 'Free';
  if (n <= 3) return '$n – Light';
  if (n <= 6) return '$n – Moderate';
  return '$n – Heavy';
}

IconData _wIcon(int n) {
  if (n == 0) return Icons.check_circle_outline;
  if (n <= 3) return Icons.info_outline;
  if (n <= 6) return Icons.warning_amber_outlined;
  return Icons.warning_rounded;
}

const _pIcons = {
  'low': Icons.arrow_downward,
  'normal': Icons.remove,
  'high': Icons.arrow_upward,
  'urgent': Icons.priority_high,
};
const _pColors = {
  'low': Color(0xFF16A34A),
  'normal': Color(0xFF2563EB),
  'high': Color(0xFFD97706),
  'urgent': Color(0xFFDC2626),
};

// ── Page ──────────────────────────────────────────────────────────────────────

class TaskCreateMultiPage extends ConsumerStatefulWidget {
  const TaskCreateMultiPage({super.key});

  @override
  ConsumerState<TaskCreateMultiPage> createState() =>
      _TaskCreateMultiPageState();
}

class _TaskCreateMultiPageState extends ConsumerState<TaskCreateMultiPage> {
  final List<_RowData> _rows = [_RowData()];
  bool _saving = false;
  String? _error;
  String? _success;
  /// Index of the task card currently being edited — drives the workload panel.
  int _focusedRowIndex = 0;

  // ── Row helpers ──────────────────────────────────────────────────────────────

  void _addRow() => setState(() {
    _rows.add(_RowData());
    _focusedRowIndex = _rows.length - 1;
  });

  void _removeRow(int i) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  void _duplicateRow(int i) {
    final s = _rows[i];
    final c = _RowData()
      ..assignedUserIds = [...s.assignedUserIds]
      ..locationId = s.locationId
      ..priority = s.priority
      ..dueDate = s.dueDate
      ..linkTasks = s.linkTasks;
    c.titleCtrl.text = s.titleCtrl.text;
    c.descCtrl.text = s.descCtrl.text;
    setState(() => _rows.insert(i + 1, c));
  }

  Future<void> _pickDueDate(int i) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _rows[i].dueDate ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _rows[i].dueDate = picked);
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _saveAll() async {
    final payload = <Map<String, dynamic>>[];

    for (final row in _rows.where((r) => r.isValid)) {
      // Generate a unique group tag if linking is enabled for 2+ users.
      final groupTag = (row.linkTasks && row.assignedUserIds.length > 1)
          ? 'linked:${DateTime.now().millisecondsSinceEpoch}'
          : null;

      for (final uid in row.assignedUserIds) {
        payload.add({
          'title': row.titleCtrl.text.trim(),
          'description': row.descCtrl.text.trim(),
          'priority': row.priority,
          'assigned_to': uid,
          'location_id': row.locationId,
          'due_date': row.dueDate!.toIso8601String(),
          if (groupTag != null) 'tags': [groupTag],
        });
      }
    }

    if (payload.isEmpty) {
      setState(() => _error =
          'Complete at least one row: assign user(s), location, task header and target date.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        ApiConstants.tasksBulkCreate,
        data: {'tasks': payload},
      );
      final created =
          (res.data['data']['created_count'] as num?)?.toInt() ?? 0;
      final failed =
          (res.data['data']['failed_count'] as num?)?.toInt() ?? 0;

      for (final r in _rows) {
        r.dispose();
      }
      _rows.clear();
      _rows.add(_RowData());

      ref.invalidate(_workloadProvider);

      setState(() {
        _saving = false;
        _success = '$created task(s) created successfully!'
            '${failed > 0 ? '  ($failed failed)' : ''}';
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error =
            'Failed to create tasks. Please check your inputs and try again.';
      });
    }
  }

  // ── Derived counts ────────────────────────────────────────────────────────────

  int get _totalTasksToCreate =>
      _rows.fold(0, (s, r) => s + r.taskCount);

  int get _readyTaskCount =>
      _rows.where((r) => r.isValid).fold(0, (s, r) => s + r.taskCount);

  // ── User picker dialog ────────────────────────────────────────────────────────

  Future<void> _showUserPicker(
    int rowIdx,
    List<OrgItem> users,
    Map<int, int> workload,
  ) async {
    final row = _rows[rowIdx];
    final chosen = <int>{...row.assignedUserIds};
    String search = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final freshUsers = ref.watch(allUsersProvider).maybeWhen(
            data: (d) => d,
            orElse: () => users,
          );
          return StatefulBuilder(
            builder: (ctx, setDlg) {
          final filtered = freshUsers
              .where((u) =>
                  u.name.toLowerCase().contains(search.toLowerCase()))
              .toList()
            ..sort((a, b) =>
                (workload[b.id] ?? 0).compareTo(workload[a.id] ?? 0));

          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.people_outline, color: _orange),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Assign Users',
                      style: TextStyle(fontSize: 16))),
              if (chosen.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${chosen.length} selected',
                      style: const TextStyle(
                          fontSize: 12,
                          color: _orange,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
            content: SizedBox(
              width: 420,
              height: 480,
              child: Column(children: [
                // Search
                TextField(
                  onChanged: (v) => setDlg(() => search = v),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon:
                        const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                // Legend
                Row(children: [
                  _LegendDot(
                      color: const Color(0xFF16A34A),
                      label: '0–3 light'),
                  const SizedBox(width: 10),
                  _LegendDot(
                      color: const Color(0xFFD97706),
                      label: '4–6 moderate'),
                  const SizedBox(width: 10),
                  _LegendDot(
                      color: const Color(0xFFDC2626),
                      label: '7+ heavy'),
                ]),
                const SizedBox(height: 6),
                const Divider(height: 1),
                // User list
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final u = filtered[i];
                      final count = workload[u.id] ?? 0;
                      final color = _wColor(count);
                      final isOn = chosen.contains(u.id);
                      return InkWell(
                        onTap: () => setDlg(() {
                          if (isOn) {
                            chosen.remove(u.id);
                          } else {
                            chosen.add(u.id);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: Row(children: [
                            Checkbox(
                              value: isOn,
                              onChanged: (v) => setDlg(() {
                                if (v == true) {
                                  chosen.add(u.id);
                                } else {
                                  chosen.remove(u.id);
                                }
                              }),
                              activeColor: _orange,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            // Colour dot
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle),
                            ),
                            Expanded(
                              child: Text(u.name,
                                  style:
                                      const TextStyle(fontSize: 13)),
                            ),
                            _WorkloadBadge(count: count),
                            const SizedBox(width: 8),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() =>
                      row.assignedUserIds = chosen.toList());
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: _orange),
                child:
                    Text('Assign ${chosen.length} user(s)'),
              ),
            ],
          );
        },
      );
    },
  ),
    );
  }

  // ── User task details popup ───────────────────────────────────────────────────

  void _showUserTasksDialog(int userId, String userName, int workloadCount) {
    final dio = ref.read(dioProvider);
    // status field only accepts a single value — fetch all and filter locally.
    final future = dio
        .get(ApiConstants.tasks, queryParameters: {
          'assigned_to': userId,
          'limit': 50,
          'sort_by': 'due_date',
          'sort_order': 'asc',
        })
        .then((res) {
          final raw = res.data['data'];
          List<Map<String, dynamic>> all;
          if (raw is List) {
            all = raw.cast<Map<String, dynamic>>();
          } else if (raw is Map && raw['tasks'] is List) {
            all = (raw['tasks'] as List).cast<Map<String, dynamic>>();
          } else {
            all = [];
          }
          // Keep only non-finalized tasks
          return all
              .where((t) =>
                  t['status'] != 'finalized')
              .toList();
        });

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding:
            const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                _wColor(workloadCount).withOpacity(0.15),
            child: Text(
              userName.isNotEmpty
                  ? userName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _wColor(workloadCount)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(userName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                        color: _wColor(workloadCount),
                        shape: BoxShape.circle),
                  ),
                  Text(
                    _wLabel(workloadCount),
                    style: TextStyle(
                        fontSize: 12,
                        color: _wColor(workloadCount),
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ],
            ),
          ),
        ]),
        content: SizedBox(
          width: 460,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade400, size: 36),
                      const SizedBox(height: 8),
                      Text('Could not load tasks',
                          style: TextStyle(
                              color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }
              final tasks = snap.data ?? [];
              if (tasks.isEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 48,
                        color: Colors.green.shade400),
                    const SizedBox(height: 12),
                    const Text('No pending tasks',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('This person is free to take on new work.',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12)),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: tasks.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                itemBuilder: (_, i) {
                  final t = tasks[i];
                  final title =
                      t['title'] as String? ?? 'Untitled';
                  final priority =
                      t['priority'] as String? ?? 'normal';
                  final status =
                      t['status'] as String? ?? 'open';
                  final due = t['due_date'] as String?;
                  final dueDate =
                      due != null ? DateTime.tryParse(due) : null;
                  final isOverdue = dueDate != null &&
                      dueDate.isBefore(DateTime.now());
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Priority dot
                        Container(
                          margin: const EdgeInsets.only(
                              top: 5, right: 10),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _pColors[priority] ??
                                Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w600),
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                children: [
                                  // Status badge
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                    decoration: BoxDecoration(
                                      color: status ==
                                              'in_progress'
                                          ? Colors.blue.shade50
                                          : Colors
                                              .orange.shade50,
                                      borderRadius:
                                          BorderRadius.circular(
                                              6),
                                    ),
                                    child: Text(
                                      status == 'in_progress'
                                          ? 'In Progress'
                                          : 'Open',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: status ==
                                                  'in_progress'
                                              ? Colors
                                                  .blue.shade700
                                              : Colors.orange
                                                  .shade700),
                                    ),
                                  ),
                                  // Priority badge
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (_pColors[priority] ??
                                              Colors.grey)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(
                                              6),
                                    ),
                                    child: Row(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                        Icon(
                                            _pIcons[priority] ??
                                                Icons.remove,
                                            size: 9,
                                            color: _pColors[
                                                    priority] ??
                                                Colors.grey),
                                        const SizedBox(width: 3),
                                        Text(
                                          priority[0]
                                                  .toUpperCase() +
                                              priority
                                                  .substring(1),
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: _pColors[
                                                      priority] ??
                                                  Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Due date
                                  if (dueDate != null)
                                    Row(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons
                                              .calendar_today_outlined,
                                          size: 10,
                                          color: isOverdue
                                              ? Colors.red.shade600
                                              : Colors
                                                  .grey.shade500,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          DateFormat('dd MMM yyyy')
                                              .format(dueDate),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isOverdue
                                                ? Colors.red.shade600
                                                : Colors
                                                    .grey.shade500,
                                            fontWeight: isOverdue
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Workload panel (only selected users) ──────────────────────────────────────

  Widget _buildWorkloadPanel(
    List<OrgItem> users,
    Map<int, int> workload,
  ) {
    final fi = _focusedRowIndex.clamp(0, _rows.length - 1);
    final focusedIds =
        _rows[fi].assignedUserIds.toSet();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: focusedIds.isEmpty
          ? Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                Icon(Icons.people_alt_outlined,
                    color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Assign users to Task ${fi + 1} — their workload will appear here.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500),
                ),
              ]),
            )
          : Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.bar_chart_outlined,
                          size: 16, color: _orange),
                      const SizedBox(width: 8),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _slate),
                          children: [
                            TextSpan(
                                text: 'Task ${fi + 1}',
                                style: const TextStyle(
                                    color: _orange)),
                            const TextSpan(
                                text: ' – Assignee Workload  '),
                            TextSpan(
                              text: '(tap card for task list)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _LegendDot(
                          color: const Color(0xFF16A34A),
                          label: '0–3 light'),
                      const SizedBox(width: 8),
                      _LegendDot(
                          color: const Color(0xFFD97706),
                          label: '4–6 moderate'),
                      const SizedBox(width: 8),
                      _LegendDot(
                          color: const Color(0xFFDC2626),
                          label: '7+ heavy'),
                    ]),
                  ),
                  const Divider(height: 1),
                  // Cards for focused row's users only
                  SizedBox(
                    height: 86,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      children: users
                          .where((u) => focusedIds.contains(u.id))
                          .map((u) {
                        final count = workload[u.id] ?? 0;
                        final color = _wColor(count);
                        return Padding(
                          padding:
                              const EdgeInsets.only(right: 8),
                          child: _WorkloadCard(
                            name: u.name,
                            count: count,
                            color: color,
                            onTap: () => _showUserTasksDialog(
                                u.id, u.name, count),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Task card ─────────────────────────────────────────────────────────────────

  Widget _buildTaskCard(
    int i,
    List<OrgItem> users,
    List<OrgItem> locations,
    Map<int, int> workload,
  ) {
    final row = _rows[i];
    final fmt = DateFormat('dd-MM-yyyy');
    final isMultiUser = row.assignedUserIds.length > 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: row.isValid
              ? const Color(0xFF16A34A).withOpacity(0.5)
              : Colors.grey.shade200,
          width: row.isValid ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ────────────────────────────────────────────────
            Row(children: [
              // Task badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: _orange.withOpacity(0.25)),
                ),
                child: Text('Task ${i + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _orange)),
              ),
              const SizedBox(width: 8),
              // Task count preview
              if (row.taskCount > 0) ...[
                Icon(Icons.arrow_forward,
                    size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text(
                  '${row.taskCount} task${row.taskCount > 1 ? 's' : ''} will be created',
                  style: TextStyle(
                      fontSize: 12,
                      color: row.taskCount > 1
                          ? _orange
                          : Colors.grey.shade600,
                      fontWeight: row.taskCount > 1
                          ? FontWeight.w600
                          : FontWeight.normal),
                ),
              ],
              const Spacer(),
              if (row.isValid)
                const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 17),
                onPressed: () => _duplicateRow(i),
                tooltip: 'Duplicate row',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              if (_rows.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 17, color: Colors.red.shade400),
                  onPressed: () => _removeRow(i),
                  tooltip: 'Remove row',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
            ]),

            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1)),

            // ── Assign users (multi-select chip area) ──────────────────────
            _buildUserChipArea(i, users, workload),

            const SizedBox(height: 12),

            // ── Link tasks toggle (only when 2+ users selected) ────────────
            if (isMultiUser) ...[
              _buildLinkToggle(i),
              const SizedBox(height: 12),
            ],

            // ── Location + Priority ────────────────────────────────────────
            LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 540;
              final locationField = DropdownButtonFormField<int>(
                value: row.locationId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Location *',
                  prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                hint: const Text('Select location'),
                items: locations
                    .map((l) => DropdownMenuItem<int>(
                          value: l.id,
                          child: Text(l.name,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => row.locationId = v),
              );
              final priorityField = DropdownButtonFormField<String>(
                value: row.priority,
                decoration: InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(
                    _pIcons[row.priority] ?? Icons.remove,
                    size: 18,
                    color: _pColors[row.priority],
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                items: ['low', 'normal', 'high', 'urgent']
                    .map((p) => DropdownMenuItem<String>(
                          value: p,
                          child: Row(children: [
                            Icon(_pIcons[p],
                                size: 14,
                                color: _pColors[p]),
                            const SizedBox(width: 6),
                            Text(
                                p[0].toUpperCase() +
                                    p.substring(1),
                                style: const TextStyle(
                                    fontSize: 13)),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => row.priority = v!),
              );
              return wide
                  ? Row(children: [
                      Expanded(flex: 3, child: locationField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: priorityField),
                    ])
                  : Column(children: [
                      locationField,
                      const SizedBox(height: 10),
                      priorityField,
                    ]);
            }),

            const SizedBox(height: 12),

            // ── Task Header + Target Date ──────────────────────────────────
            LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 540;
              final titleF = TextField(
                controller: row.titleCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Task Header *',
                  prefixIcon:
                      const Icon(Icons.title_outlined, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              );
              final dateF = InkWell(
                onTap: () => _pickDueDate(i),
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Target Date *',
                    prefixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  child: Text(
                    row.dueDate != null
                        ? fmt.format(row.dueDate!)
                        : 'Select date',
                    style: TextStyle(
                        fontSize: 14,
                        color: row.dueDate != null
                            ? Colors.black87
                            : Colors.grey.shade500),
                  ),
                ),
              );
              return wide
                  ? Row(children: [
                      Expanded(flex: 3, child: titleF),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: dateF),
                    ])
                  : Column(children: [
                      titleF,
                      const SizedBox(height: 10),
                      dateF,
                    ]);
            }),

            const SizedBox(height: 12),

            // ── Description ────────────────────────────────────────────────
            TextField(
              controller: row.descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon:
                    const Icon(Icons.notes_outlined, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── User chip area ────────────────────────────────────────────────────────────

  Widget _buildUserChipArea(
    int i,
    List<OrgItem> users,
    Map<int, int> workload,
  ) {
    final row = _rows[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assign Owner(s) *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _slate)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Chips for already-selected users
            ...row.assignedUserIds.map((uid) {
              final u = users.where((x) => x.id == uid).firstOrNull;
              final name = u?.name ?? 'User $uid';
              final count = workload[uid] ?? 0;
              final color = _wColor(count);
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: color.withOpacity(0.18),
                  radius: 12,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(name,
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                ]),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() {
                  row.assignedUserIds.remove(uid);
                  _focusedRowIndex = i;
                }),
                backgroundColor: color.withOpacity(0.06),
                side: BorderSide(color: color.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
              );
            }),

            // + Assign Users button
            ActionChip(
              avatar: Icon(
                row.assignedUserIds.isEmpty
                    ? Icons.person_add_outlined
                    : Icons.add,
                size: 16,
                color: row.assignedUserIds.isEmpty
                    ? Colors.red.shade600
                    : _orange,
              ),
              label: Text(
                row.assignedUserIds.isEmpty
                    ? 'Assign User(s)  *'
                    : '+ Add User',
                style: TextStyle(
                  fontSize: 12,
                  color: row.assignedUserIds.isEmpty
                      ? Colors.red.shade600
                      : _orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                setState(() => _focusedRowIndex = i);
                _showUserPicker(i, users, workload);
              },
              backgroundColor: row.assignedUserIds.isEmpty
                  ? Colors.red.shade50
                  : _orange.withOpacity(0.06),
              side: BorderSide(
                color: row.assignedUserIds.isEmpty
                    ? Colors.red.shade200
                    : _orange.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Link toggle ───────────────────────────────────────────────────────────────

  Widget _buildLinkToggle(int i) {
    final row = _rows[i];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: row.linkTasks
            ? const Color(0xFF1D4ED8).withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: row.linkTasks
              ? const Color(0xFF1D4ED8).withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(children: [
        Icon(
          row.linkTasks ? Icons.link : Icons.link_off,
          size: 18,
          color: row.linkTasks
              ? const Color(0xFF1D4ED8)
              : Colors.grey.shade500,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Link these ${row.assignedUserIds.length} tasks together',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: row.linkTasks
                      ? const Color(0xFF1D4ED8)
                      : Colors.grey.shade700,
                ),
              ),
              Text(
                row.linkTasks
                    ? 'All ${row.assignedUserIds.length} tasks will share a link tag — '
                        'visible in the task list as a group.'
                    : 'Enable to tag all tasks from this row so assignees '
                        'know they\'re working on the same job.',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        Switch(
          value: row.linkTasks,
          onChanged: (v) => setState(() => row.linkTasks = v),
          activeColor: const Color(0xFF1D4ED8),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUsersProvider).maybeWhen(
          data: (d) => d,
          orElse: () => <OrgItem>[],
        );
    final locations = ref.watch(locationsProvider(null)).maybeWhen(
          data: (d) => d,
          orElse: () => <OrgItem>[],
        );
    final workload = ref.watch(_workloadProvider).maybeWhen(
          data: (d) => d,
          orElse: () => <int, int>{},
        );
    final authUser = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page header ────────────────────────────────────────────────
            Row(children: [
              IconButton(
                onPressed: () => context.go('/tasks'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Multiple Tasks',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (authUser != null)
                      Text(
                        'Raised by ${authUser.name}'
                        '${authUser.companyName != null ? '  ·  ${authUser.companyName}' : ''}'
                        '  ·  ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 12),

            // ── Feedback ──────────────────────────────────────────────────
            if (_success != null)
              _Banner(
                  message: _success!,
                  color: const Color(0xFF16A34A),
                  icon: Icons.check_circle_outline,
                  onDismiss: () => setState(() => _success = null)),
            if (_error != null)
              _Banner(
                  message: _error!,
                  color: const Color(0xFFDC2626),
                  icon: Icons.error_outline,
                  onDismiss: () => setState(() => _error = null)),

            // ── Workload panel (selected users only) ──────────────────────
            _buildWorkloadPanel(users, workload),

            // ── Task cards ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (_, i) =>
                    _buildTaskCard(i, users, locations, workload),
              ),
            ),

            const SizedBox(height: 8),

            // ── Bottom action bar ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 13, color: _slate),
                        children: [
                          TextSpan(
                              text: '${_rows.length}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          const TextSpan(text: ' task row(s)  ·  '),
                          TextSpan(
                              text: '$_totalTasksToCreate',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _orange)),
                          const TextSpan(
                              text: ' tasks total  ·  '),
                          TextSpan(
                              text: '$_readyTaskCount ready',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      const Color(0xFF16A34A))),
                        ],
                      ),
                    ),
                    Text(
                      'Required per row: user(s), location, task header, target date',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('+ Add Task Row'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side:
                        BorderSide(color: Colors.green.shade400),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed:
                      (_saving || _readyTaskCount == 0) ? null : _saveAll,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.save_alt_outlined,
                          size: 18),
                  label: Text(_saving
                      ? 'Saving...'
                      : 'Save All  ($_readyTaskCount tasks)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _WorkloadCard extends StatelessWidget {
  const _WorkloadCard({
    required this.name,
    required this.count,
    required this.color,
    this.onTap,
  });

  final String name;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tap to see pending tasks',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            // Tap hint icon
            Icon(Icons.open_in_new,
                size: 12,
                color: color.withOpacity(0.6)),
          ]),
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(_wLabel(count),
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ],
      ),
    ), // Container
    ), // InkWell
    ); // Tooltip
  }
}

class _WorkloadBadge extends StatelessWidget {
  const _WorkloadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = _wColor(count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_wIcon(count), size: 12, color: c),
        const SizedBox(width: 4),
        Text(_wLabel(count),
            style: TextStyle(
                fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
    ]);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
  });

  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13))),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 18),
          onPressed: onDismiss,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ]),
    );
  }
}
