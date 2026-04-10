import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/dio_client.dart';
import '../../org/providers/org_provider.dart';

// ── Lightweight models ────────────────────────────────────────────────────────

class _TaskItem {
  final int id;
  final String title;
  final String priority;
  final String status;
  final String? department;
  final String? location;
  final String? assignee;
  final DateTime? dueDate;
  final DateTime createdAt;

  const _TaskItem({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    this.department,
    this.location,
    this.assignee,
    this.dueDate,
    required this.createdAt,
  });

  factory _TaskItem.fromJson(Map<String, dynamic> j) => _TaskItem(
        id: j['id'],
        title: j['title'] ?? '',
        priority: j['priority'] ?? 'normal',
        status: j['status'] ?? 'open',
        department: (j['department'] as Map?)?['name'] as String?,
        location: (j['location'] as Map?)?['name'] as String?,
        assignee: (j['assignee'] as Map?)?['name'] as String?,
        dueDate: j['due_date'] != null ? DateTime.tryParse(j['due_date']) : null,
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
      );
}

class _UserItem {
  final int id;
  final String name;
  final String? designation;
  final String? departmentName;
  final String role;
  final int openCount;
  final int inProgressCount;

  const _UserItem({
    required this.id,
    required this.name,
    this.designation,
    this.departmentName,
    required this.role,
    this.openCount = 0,
    this.inProgressCount = 0,
  });

  factory _UserItem.fromOrgItem(OrgItem o) => _UserItem(
        id: o.id,
        name: o.name,
        role: '',
        departmentName: o.companyName,
      );

  int get activeCount => openCount + inProgressCount;
}

// ── Providers ─────────────────────────────────────────────────────────────────

// Fetch open/in-progress tasks for bulk assign (up to 200)
final _bulkTasksProvider = FutureProvider.autoDispose.family<List<_TaskItem>, Map<String, dynamic>>((ref, filters) async {
  final dio = ref.watch(dioProvider);
  final params = <String, dynamic>{
    'page': 1,
    'limit': 200,
    ...filters,
  };
  final res = await dio.get(ApiConstants.tasks, queryParameters: params);
  final List data = res.data['data']['tasks'] ?? [];
  return data.map((j) => _TaskItem.fromJson(j as Map<String, dynamic>)).toList();
});

// Fetch users with workload summary from report summary
final _usersWorkloadProvider = FutureProvider.autoDispose<List<_UserItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  // Get all users
  final usersRes = await dio.get(ApiConstants.users, queryParameters: {'limit': 200, 'is_active': true});
  final List usersData = usersRes.data['data']['users'] ?? [];

  // Get summary workload
  final summaryRes = await dio.get(ApiConstants.reportSummary);
  final List byUserData = summaryRes.data['data']['byUser'] ?? [];

  final workloadMap = <int, Map>{};
  for (final row in byUserData) {
    final userId = (row['assignee'] as Map?)?['id'];
    if (userId != null) workloadMap[userId] = row as Map;
  }

  return usersData.map((u) {
    final uid = u['id'] as int;
    final w = workloadMap[uid];
    return _UserItem(
      id: uid,
      name: u['name'] ?? '',
      designation: u['designation'] as String?,
      departmentName: (u['department'] as Map?)?['name'] as String?,
      role: u['role'] ?? '',
      openCount: w != null ? (w['open'] as num?)?.toInt() ?? 0 : 0,
      inProgressCount: w != null ? (w['in_progress'] as num?)?.toInt() ?? 0 : 0,
    );
  }).toList();
});

// Pending tasks for a specific user (workload preview)
final _userPendingTasksProvider = FutureProvider.autoDispose.family<List<_TaskItem>, int>((ref, userId) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get(ApiConstants.reportWorklist, queryParameters: {
    'user_id': userId,
    'limit': 50,
    'page': 1,
  });
  final List data = res.data['data']['tasks'] ?? [];
  return data.map((j) => _TaskItem.fromJson(j as Map<String, dynamic>)).toList();
});

// ── Main Page ─────────────────────────────────────────────────────────────────

class TaskBulkAssignPage extends ConsumerStatefulWidget {
  const TaskBulkAssignPage({super.key});

  @override
  ConsumerState<TaskBulkAssignPage> createState() => _TaskBulkAssignPageState();
}

class _TaskBulkAssignPageState extends ConsumerState<TaskBulkAssignPage> {
  final Set<int> _selectedTaskIds = {};
  final Set<int> _selectedUserIds = {};
  String _taskSearch = '';
  String _userSearch = '';
  String _taskStatus = 'open';
  bool _assigning = false;
  String? _assignError;
  String? _assignSuccess;

  // Task filter params
  Map<String, dynamic> get _taskFilters => {
        if (_taskStatus.isNotEmpty) 'status': _taskStatus,
      };

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Bulk Task Assignment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (_selectedTaskIds.isNotEmpty || _selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '${_selectedTaskIds.length} task(s) · ${_selectedUserIds.length} user(s)',
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar / feedback
          if (_assignSuccess != null)
            _Banner(message: _assignSuccess!, color: const Color(0xFF10B981), onDismiss: () => setState(() => _assignSuccess = null)),
          if (_assignError != null)
            _Banner(message: _assignError!, color: const Color(0xFFEF4444), onDismiss: () => setState(() => _assignError = null)),

          // Two panels
          Expanded(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _TaskPanel(
                        selectedIds: _selectedTaskIds,
                        search: _taskSearch,
                        status: _taskStatus,
                        filters: _taskFilters,
                        onToggle: _toggleTask,
                        onSelectAll: _selectAllTasks,
                        onSearchChanged: (v) => setState(() => _taskSearch = v),
                        onStatusChanged: (v) => setState(() { _taskStatus = v; _selectedTaskIds.clear(); }),
                      )),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 2, child: _UserPanel(
                        selectedIds: _selectedUserIds,
                        search: _userSearch,
                        onToggle: _toggleUser,
                        onSearchChanged: (v) => setState(() => _userSearch = v),
                        onViewWorkload: _showWorkloadDialog,
                      )),
                    ],
                  )
                : _NarrowLayout(
                    selectedTaskIds: _selectedTaskIds,
                    selectedUserIds: _selectedUserIds,
                    taskSearch: _taskSearch,
                    userSearch: _userSearch,
                    taskStatus: _taskStatus,
                    taskFilters: _taskFilters,
                    onToggleTask: _toggleTask,
                    onSelectAllTasks: _selectAllTasks,
                    onTaskSearchChanged: (v) => setState(() => _taskSearch = v),
                    onStatusChanged: (v) => setState(() { _taskStatus = v; _selectedTaskIds.clear(); }),
                    onToggleUser: _toggleUser,
                    onUserSearchChanged: (v) => setState(() => _userSearch = v),
                    onViewWorkload: _showWorkloadDialog,
                  ),
          ),

          // Bottom action bar
          _AssignBar(
            taskCount: _selectedTaskIds.length,
            userCount: _selectedUserIds.length,
            assigning: _assigning,
            onAssign: _doAssign,
          ),
        ],
      ),
    );
  }

  void _toggleTask(int id) => setState(() {
        if (_selectedTaskIds.contains(id)) {
          _selectedTaskIds.remove(id);
        } else {
          _selectedTaskIds.add(id);
        }
      });

  void _selectAllTasks(List<_TaskItem> tasks) {
    setState(() {
      if (_selectedTaskIds.length == tasks.length) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds
          ..clear()
          ..addAll(tasks.map((t) => t.id));
      }
    });
  }

  void _toggleUser(int id) => setState(() {
        if (_selectedUserIds.contains(id)) {
          _selectedUserIds.remove(id);
        } else {
          _selectedUserIds.add(id);
        }
      });

  void _showWorkloadDialog(int userId, String userName) {
    showDialog(
      context: context,
      builder: (_) => _WorkloadDialog(userId: userId, userName: userName),
    );
  }

  Future<void> _doAssign() async {
    if (_selectedTaskIds.isEmpty || _selectedUserIds.isEmpty) return;

    final multiUser = _selectedUserIds.length > 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Assignment'),
        content: Text(
          multiUser
              ? 'This will create ${_selectedTaskIds.length * _selectedUserIds.length} new tasks (copies of ${_selectedTaskIds.length} task(s) for ${_selectedUserIds.length} user(s)).\n\nContinue?'
              : 'This will reassign ${_selectedTaskIds.length} task(s) to the selected user.\n\nContinue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Assign', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _assigning = true; _assignError = null; _assignSuccess = null; });

    try {
      final res = await ref.read(dioProvider).post(
        ApiConstants.tasksBulkAssign,
        data: {
          'task_ids': _selectedTaskIds.toList(),
          'user_ids': _selectedUserIds.toList(),
        },
      );
      final data = res.data['data'] as Map<String, dynamic>;
      setState(() {
        _assigning = false;
        _assignSuccess = 'Done! ${data['assigned_count']} assignment(s) created across '
            '${data['user_count']} user(s).';
        _selectedTaskIds.clear();
        _selectedUserIds.clear();
      });
    } catch (e) {
      final msg = (e as dynamic).response?.data?['message'] ?? e.toString();
      setState(() { _assigning = false; _assignError = 'Error: $msg'; });
    }
  }
}

// ── Task Panel ────────────────────────────────────────────────────────────────

class _TaskPanel extends ConsumerWidget {
  final Set<int> selectedIds;
  final String search;
  final String status;
  final Map<String, dynamic> filters;
  final void Function(int) onToggle;
  final void Function(List<_TaskItem>) onSelectAll;
  final void Function(String) onSearchChanged;
  final void Function(String) onStatusChanged;

  const _TaskPanel({
    required this.selectedIds,
    required this.search,
    required this.status,
    required this.filters,
    required this.onToggle,
    required this.onSelectAll,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(_bulkTasksProvider(filters));

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.task_alt, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    const Text('Select Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    if (selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${selectedIds.length} selected',
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search tasks...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusDropdown(value: status, onChanged: onStatusChanged),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (tasks) {
                final filtered = tasks.where((t) =>
                    search.isEmpty ||
                    t.title.toLowerCase().contains(search.toLowerCase())).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.black26),
                        SizedBox(height: 8),
                        Text('No tasks found', style: TextStyle(color: Colors.black38)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Select all bar
                    InkWell(
                      onTap: () => onSelectAll(filtered),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            Checkbox(
                              value: selectedIds.length == filtered.length && filtered.isNotEmpty,
                              tristate: true,
                              onChanged: (_) => onSelectAll(filtered),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            Text(
                              selectedIds.length == filtered.length
                                  ? 'Deselect all (${filtered.length})'
                                  : 'Select all (${filtered.length})',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                        itemBuilder: (ctx, i) {
                          final task = filtered[i];
                          final isSelected = selectedIds.contains(task.id);
                          return _TaskRow(
                            task: task,
                            isSelected: isSelected,
                            onTap: () => onToggle(task.id),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final _TaskItem task;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaskRow({required this.task, required this.isSelected, required this.onTap});

  Color get _priorityColor {
    switch (task.priority) {
      case 'urgent': return const Color(0xFFEF4444);
      case 'high': return const Color(0xFFF97316);
      case 'normal': return const Color(0xFF3B82F6);
      default: return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overdue = task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        task.status != 'finalized';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? const Color(0xFFEFF6FF) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _Badge(task.priority, _priorityColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (task.department != null)
                        _MetaChip(Icons.apartment_outlined, task.department!),
                      if (task.location != null)
                        _MetaChip(Icons.location_on_outlined, task.location!),
                      if (task.assignee != null)
                        _MetaChip(Icons.person_outline, task.assignee!),
                      if (task.dueDate != null)
                        _MetaChip(
                          Icons.calendar_today_outlined,
                          '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                          color: overdue ? const Color(0xFFEF4444) : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User Panel ────────────────────────────────────────────────────────────────

class _UserPanel extends ConsumerWidget {
  final Set<int> selectedIds;
  final String search;
  final void Function(int) onToggle;
  final void Function(String) onSearchChanged;
  final void Function(int, String) onViewWorkload;

  const _UserPanel({
    required this.selectedIds,
    required this.search,
    required this.onToggle,
    required this.onSearchChanged,
    required this.onViewWorkload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_usersWorkloadProvider);

    return Container(
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    const Text('Select Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    if (selectedIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${selectedIds.length} selected',
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: onSearchChanged,
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (users) {
                final filtered = users.where((u) =>
                    u.name.toLowerCase().contains(search.toLowerCase())).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No users found'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final user = filtered[i];
                    final isSelected = selectedIds.contains(user.id);
                    return _UserRow(
                      user: user,
                      isSelected: isSelected,
                      onTap: () => onToggle(user.id),
                      onViewWorkload: () => onViewWorkload(user.id, user.name),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final _UserItem user;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onViewWorkload;

  const _UserRow({
    required this.user,
    required this.isSelected,
    required this.onTap,
    required this.onViewWorkload,
  });

  Color get _loadColor {
    if (user.activeCount >= 10) return const Color(0xFFEF4444);
    if (user.activeCount >= 5) return const Color(0xFFF97316);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: const Color(0xFF10B981),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1E293B),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (user.designation != null && user.designation!.isNotEmpty) user.designation!,
                      if (user.departmentName != null && user.departmentName!.isNotEmpty) user.departmentName!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Workload badge
            Tooltip(
              message: '${user.activeCount} active tasks',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _loadColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${user.activeCount}',
                  style: TextStyle(color: _loadColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // View workload button
            Tooltip(
              message: 'View pending tasks',
              child: IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                color: const Color(0xFF64748B),
                onPressed: onViewWorkload,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Narrow (mobile) layout ────────────────────────────────────────────────────

class _NarrowLayout extends StatefulWidget {
  final Set<int> selectedTaskIds;
  final Set<int> selectedUserIds;
  final String taskSearch;
  final String userSearch;
  final String taskStatus;
  final Map<String, dynamic> taskFilters;
  final void Function(int) onToggleTask;
  final void Function(List<_TaskItem>) onSelectAllTasks;
  final void Function(String) onTaskSearchChanged;
  final void Function(String) onStatusChanged;
  final void Function(int) onToggleUser;
  final void Function(String) onUserSearchChanged;
  final void Function(int, String) onViewWorkload;

  const _NarrowLayout({
    required this.selectedTaskIds,
    required this.selectedUserIds,
    required this.taskSearch,
    required this.userSearch,
    required this.taskStatus,
    required this.taskFilters,
    required this.onToggleTask,
    required this.onSelectAllTasks,
    required this.onTaskSearchChanged,
    required this.onStatusChanged,
    required this.onToggleUser,
    required this.onUserSearchChanged,
    required this.onViewWorkload,
  });

  @override
  State<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends State<_NarrowLayout> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF3B82F6),
          tabs: [
            Tab(text: 'Tasks (${widget.selectedTaskIds.length})'),
            Tab(text: 'Users (${widget.selectedUserIds.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TaskPanel(
                selectedIds: widget.selectedTaskIds,
                search: widget.taskSearch,
                status: widget.taskStatus,
                filters: widget.taskFilters,
                onToggle: widget.onToggleTask,
                onSelectAll: widget.onSelectAllTasks,
                onSearchChanged: widget.onTaskSearchChanged,
                onStatusChanged: widget.onStatusChanged,
              ),
              _UserPanel(
                selectedIds: widget.selectedUserIds,
                search: widget.userSearch,
                onToggle: widget.onToggleUser,
                onSearchChanged: widget.onUserSearchChanged,
                onViewWorkload: widget.onViewWorkload,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Workload Dialog ───────────────────────────────────────────────────────────

class _WorkloadDialog extends ConsumerWidget {
  final int userId;
  final String userName;

  const _WorkloadDialog({required this.userId, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(_userPendingTasksProvider(userId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pending Workload',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(userName,
                            style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: tasksAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Error loading tasks: $e'),
                ),
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF10B981)),
                          SizedBox(height: 12),
                          Text('No pending tasks', style: TextStyle(fontWeight: FontWeight.w500)),
                          SizedBox(height: 4),
                          Text('This user is available for assignment.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  // Status summary chips
                  final openCount = tasks.where((t) => t.status == 'open').length;
                  final inProgressCount = tasks.where((t) => t.status == 'in_progress').length;
                  final overdueCount = tasks.where((t) =>
                      t.dueDate != null &&
                      t.dueDate!.isBefore(DateTime.now()) &&
                      t.status != 'finalized').length;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Summary row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            _StatPill('Open', openCount, const Color(0xFF3B82F6)),
                            const SizedBox(width: 8),
                            _StatPill('In Progress', inProgressCount, const Color(0xFFF59E0B)),
                            const SizedBox(width: 8),
                            if (overdueCount > 0)
                              _StatPill('Overdue', overdueCount, const Color(0xFFEF4444)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                          itemBuilder: (ctx, i) {
                            final t = tasks[i];
                            final overdue = t.dueDate != null &&
                                t.dueDate!.isBefore(DateTime.now()) &&
                                t.status != 'finalized';
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                              leading: Icon(
                                overdue
                                    ? Icons.warning_amber_outlined
                                    : t.status == 'in_progress'
                                        ? Icons.play_circle_outline
                                        : Icons.radio_button_unchecked,
                                size: 18,
                                color: overdue
                                    ? const Color(0xFFEF4444)
                                    : t.status == 'in_progress'
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF94A3B8),
                              ),
                              title: Text(t.title,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              subtitle: t.dueDate != null
                                  ? Text(
                                      'Due: ${t.dueDate!.day}/${t.dueDate!.month}/${t.dueDate!.year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: overdue ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                      ),
                                    )
                                  : null,
                              trailing: _PriorityDot(t.priority),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Assign Bar ────────────────────────────────────────────────────────────────

class _AssignBar extends StatelessWidget {
  final int taskCount;
  final int userCount;
  final bool assigning;
  final VoidCallback onAssign;

  const _AssignBar({
    required this.taskCount,
    required this.userCount,
    required this.assigning,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final canAssign = taskCount > 0 && userCount > 0 && !assigning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          // Summary text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  taskCount > 0 && userCount > 0
                      ? userCount > 1
                          ? 'Will create ${taskCount * userCount} tasks (${taskCount} × ${userCount} users)'
                          : 'Will assign $taskCount task(s) to 1 user'
                      : 'Select tasks and users to assign',
                  style: TextStyle(
                    fontSize: 13,
                    color: canAssign ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                    fontWeight: canAssign ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                if (userCount > 1)
                  const Text(
                    'Each task will be duplicated for every selected user',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: canAssign ? onAssign : null,
              icon: assigning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assignment_turned_in_outlined, size: 18),
              label: Text(
                assigning ? 'Assigning...' : 'Assign Tasks',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _StatusDropdown extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opts = [
      ('', 'All'),
      ('open', 'Open'),
      ('in_progress', 'In Progress'),
      ('reopened', 'Reopened'),
    ];
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: opts.map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => onChanged(v ?? ''),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MetaChip(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF94A3B8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  final String priority;
  const _PriorityDot(this.priority);

  Color get _color {
    switch (priority) {
      case 'urgent': return const Color(0xFFEF4444);
      case 'high': return const Color(0xFFF97316);
      case 'normal': return const Color(0xFF3B82F6);
      default: return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: priority,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final Color color;
  final VoidCallback onDismiss;
  const _Banner({required this.message, required this.color, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}
