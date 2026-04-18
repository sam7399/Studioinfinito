import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

// ── Sort options ──────────────────────────────────────────────────────────────

class _SortOption {
  final String label;
  final String sortBy;
  final String sortOrder;
  const _SortOption(this.label, this.sortBy, this.sortOrder);
}

const _sortOptions = [
  _SortOption('Newest First', 'created_at', 'desc'),
  _SortOption('Oldest First', 'created_at', 'asc'),
  _SortOption('Due Soon', 'due_date', 'asc'),
  _SortOption('Due Late', 'due_date', 'desc'),
  _SortOption('Priority ↑ (Low→Urgent)', 'priority', 'asc'),
  _SortOption('Priority ↓ (Urgent→Low)', 'priority', 'desc'),
  _SortOption('Status A→Z', 'status', 'asc'),
  _SortOption('Title A→Z', 'title', 'asc'),
  _SortOption('Title Z→A', 'title', 'desc'),
  _SortOption('Last Updated', 'updated_at', 'desc'),
];

// ── Page ──────────────────────────────────────────────────────────────────────

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
  final _scrollControllers = [ScrollController(), ScrollController()];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Sync scroll for infinite load
    for (var i = 0; i < 2; i++) {
      final idx = i;
      _scrollControllers[idx].addListener(() {
        final sc = _scrollControllers[idx];
        if (sc.position.pixels >= sc.position.maxScrollExtent - 200) {
          if (ref.read(taskProvider).activeTab == idx) {
            ref.read(taskProvider.notifier).fetchMore();
          }
        }
      });
    }

    // Sync search field with provider state on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final q = ref.read(taskProvider).searchQuery;
      if (_searchCtrl.text != q) _searchCtrl.text = q;
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    ref.read(taskProvider.notifier).setTab(_tabController.index);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    ref.read(taskProvider.notifier).clearFilters();
  }

  Future<void> _pickDateRange() async {
    final s = ref.read(taskProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: s.dueDateFrom != null && s.dueDateTo != null
          ? DateTimeRange(start: s.dueDateFrom!, end: s.dueDateTo!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: GemColors.green,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      ref.read(taskProvider.notifier).setDateRange(range.start, range.end);
    } else if (s.dueDateFrom != null) {
      ref.read(taskProvider.notifier).setDateRange(null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    final userRole = ref.watch(authProvider).user?.role ?? '';
    final canCreate = true;
    final isWide = MediaQuery.of(context).size.width > 700;

    // Sync tab controller if provider tab changed externally
    if (_tabController.index != state.activeTab) {
      _tabController.animateTo(state.activeTab);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top header ─────────────────────────────────────────────
          _Header(canCreate: canCreate, isWide: isWide),

          // ── Search + filters ────────────────────────────────────────
          _SearchFilterBar(
            searchCtrl: _searchCtrl,
            state: state,
            onPickDateRange: _pickDateRange,
            onClearFilters: _clearFilters,
          ),

          // ── Tabs ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: GemColors.green,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: GemColors.green,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 16),
                      const SizedBox(width: 6),
                      const Text('Assigned to Me'),
                      if (state.assignedToMe.initialized) ...[
                        const SizedBox(width: 6),
                        _CountBadge(state.assignedToMe.tasks.length,
                            state.assignedToMe.hasMore),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.send_outlined, size: 16),
                      const SizedBox(width: 6),
                      const Text('Assigned by Me'),
                      if (state.assignedByMe.initialized) ...[
                        const SizedBox(width: 6),
                        _CountBadge(state.assignedByMe.tasks.length,
                            state.assignedByMe.hasMore),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sort row ────────────────────────────────────────────────
          _SortBar(state: state),

          // ── Task lists ──────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TaskTabView(
                  tabData: state.assignedToMe,
                  tab: 0,
                  scrollController: _scrollControllers[0],
                ),
                _TaskTabView(
                  tabData: state.assignedByMe,
                  tab: 1,
                  scrollController: _scrollControllers[1],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool canCreate;
  final bool isWide;
  const _Header({required this.canCreate, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tasks',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('Manage and track your work',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
          const Spacer(),
          if (canCreate) ...[
            if (isWide)
              OutlinedButton.icon(
                onPressed: () => context.go('/tasks/create-multi'),
                icon: const Icon(Icons.playlist_add, size: 16),
                label: const Text('Bulk Create',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10)),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => context.go('/tasks/create'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Task', style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                  backgroundColor: GemColors.green,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Search + Filter bar ───────────────────────────────────────────────────────

class _SearchFilterBar extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final TaskListState state;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearFilters;

  const _SearchFilterBar({
    required this.searchCtrl,
    required this.state,
    required this.onPickDateRange,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDateRange = state.dueDateFrom != null || state.dueDateTo != null;
    final fmt = DateFormat('MMM d');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Search field
          TextField(
            controller: searchCtrl,
            onChanged: (v) =>
                ref.read(taskProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText:
                  'Search by title, description, person, department, location...',
              hintStyle:
                  TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon:
                  Icon(Icons.search, size: 18, color: Colors.grey.shade400),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        searchCtrl.clear();
                        ref.read(taskProvider.notifier).setSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: GemColors.green, width: 1.5)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status
                _ChipDropdown<String?>(
                  icon: Icons.circle_outlined,
                  label: state.statusFilter == null
                      ? 'All Status'
                      : _statusLabel(state.statusFilter!),
                  active: state.statusFilter != null,
                  items: const [
                    PopupMenuItem(value: null, child: Text('All Status')),
                    PopupMenuItem(value: 'open', child: Text('Open')),
                    PopupMenuItem(
                        value: 'in_progress', child: Text('In Progress')),
                    PopupMenuItem(
                        value: 'complete_pending_review',
                        child: Text('Pending Review')),
                    PopupMenuItem(
                        value: 'finalized', child: Text('Finalized')),
                    PopupMenuItem(
                        value: 'reopened', child: Text('Reopened')),
                  ],
                  onSelected: (v) =>
                      ref.read(taskProvider.notifier).setStatusFilter(v),
                ),
                const SizedBox(width: 8),
                // Priority
                _ChipDropdown<String?>(
                  icon: Icons.flag_outlined,
                  label: state.priorityFilter == null
                      ? 'All Priority'
                      : _capitalize(state.priorityFilter!),
                  active: state.priorityFilter != null,
                  items: const [
                    PopupMenuItem(value: null, child: Text('All Priority')),
                    PopupMenuItem(value: 'low', child: Text('Low')),
                    PopupMenuItem(value: 'normal', child: Text('Normal')),
                    PopupMenuItem(value: 'high', child: Text('High')),
                    PopupMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onSelected: (v) =>
                      ref.read(taskProvider.notifier).setPriorityFilter(v),
                ),
                const SizedBox(width: 8),
                // Date range
                GestureDetector(
                  onTap: onPickDateRange,
                  child: _FilterChip(
                    icon: Icons.date_range_outlined,
                    label: hasDateRange
                        ? '${state.dueDateFrom != null ? fmt.format(state.dueDateFrom!) : '?'} – ${state.dueDateTo != null ? fmt.format(state.dueDateTo!) : '?'}'
                        : 'Due Date Range',
                    active: hasDateRange,
                  ),
                ),
                const SizedBox(width: 8),
                // Clear all
                if (state.hasActiveFilters)
                  TextButton.icon(
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                // Refresh
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.read(taskProvider.notifier).refreshAll(),
                  color: Colors.grey.shade600,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'open' => 'Open',
        'in_progress' => 'In Progress',
        'complete_pending_review' => 'Pending Review',
        'finalized' => 'Finalized',
        'reopened' => 'Reopened',
        _ => s,
      };

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Sort bar ──────────────────────────────────────────────────────────────────

class _SortBar extends ConsumerWidget {
  final TaskListState state;
  const _SortBar({required this.state});

  String _currentSortLabel() {
    for (final opt in _sortOptions) {
      if (opt.sortBy == state.sortBy && opt.sortOrder == state.sortOrder) {
        return opt.label;
      }
    }
    return 'Sort';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.sort, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text('Sort:',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          _ChipDropdown<String>(
            icon: Icons.swap_vert,
            label: _currentSortLabel(),
            active: state.sortBy != 'created_at' || state.sortOrder != 'desc',
            items: _sortOptions
                .map((o) => PopupMenuItem(
                      value: '${o.sortBy}|${o.sortOrder}',
                      child: Text(o.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  (o.sortBy == state.sortBy &&
                                          o.sortOrder == state.sortOrder)
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                    ))
                .toList(),
            onSelected: (v) {
              if (v == null) return;
              final parts = v.split('|');
              ref
                  .read(taskProvider.notifier)
                  .setSort(parts[0], parts[1]);
            },
          ),
          const Spacer(),
          Builder(builder: (ctx) {
            final count = state.activeTabData.tasks.length;
            final hasMore = state.activeTabData.hasMore;
            if (!state.activeTabData.initialized) return const SizedBox();
            return Text(
              hasMore ? '$count+ tasks' : '$count task${count == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            );
          }),
        ],
      ),
    );
  }
}

// ── Tab view ──────────────────────────────────────────────────────────────────

class _TaskTabView extends ConsumerWidget {
  final TabTaskData tabData;
  final int tab;
  final ScrollController scrollController;

  const _TaskTabView({
    required this.tabData,
    required this.tab,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!tabData.initialized && tabData.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tabData.error != null && tabData.tasks.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(tabData.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            onPressed: () =>
                ref.read(taskProvider.notifier).setTab(tab),
          ),
        ]),
      );
    }

    if (tabData.initialized && tabData.tasks.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            tab == 0
                ? Icons.inbox_outlined
                : Icons.assignment_outlined,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            tab == 0
                ? 'No tasks assigned to you'
                : 'You haven\'t created any tasks',
            style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting filters or search terms',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          await ref.read(taskProvider.notifier).setTab(tab),
      color: GemColors.green,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        itemCount: tabData.tasks.length + (tabData.hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == tabData.tasks.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return _TaskCard(task: tabData.tasks[i], tab: tab);
        },
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final int tab; // 0=assignedToMe, 1=assignedByMe

  const _TaskCard({required this.task, required this.tab});

  Color _priorityColor(String p) => switch (p) {
        'urgent' => const Color(0xFFEF4444),
        'high' => const Color(0xFFF97316),
        'normal' => const Color(0xFF3B82F6),
        _ => const Color(0xFF9CA3AF),
      };

  Color _statusColor(String s) => switch (s) {
        'finalized' => const Color(0xFF10B981),
        'in_progress' => const Color(0xFF8B5CF6),
        'complete_pending_review' => const Color(0xFFF59E0B),
        'reopened' => const Color(0xFFEF4444),
        _ => const Color(0xFF9CA3AF),
      };

  String _statusLabel(String s) => switch (s) {
        'open' => 'Open',
        'in_progress' => 'In Progress',
        'complete_pending_review' => 'Pending Review',
        'finalized' => 'Finalized',
        'reopened' => 'Reopened',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;
    final restricted = task.isRestricted;
    final priColor =
        restricted ? Colors.blueGrey.shade300 : _priorityColor(task.priority);
    final now = DateTime.now();
    final daysLeft = task.dueDate != null
        ? task.dueDate!.difference(now).inDays
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isOverdue && !restricted
            ? Border.all(color: Colors.red.shade200)
            : restricted
                ? Border.all(color: Colors.blueGrey.shade100)
                : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => context.go('/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority stripe
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: priColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: restricted
                    ? _RestrictedContent(task: task)
                    : _FullContent(
                        task: task,
                        tab: tab,
                        daysLeft: daysLeft,
                        isOverdue: isOverdue,
                        statusColor: _statusColor(task.status),
                        statusLabel: _statusLabel(task.status),
                        priorityColor: priColor,
                      ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestrictedContent extends StatelessWidget {
  final TaskModel task;
  const _RestrictedContent({required this.task});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.lock_outline, size: 13, color: Colors.blueGrey.shade400),
          const SizedBox(width: 4),
          Expanded(
            child: Text(task.title,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.blueGrey.shade600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 5),
        Text('Cross-department · restricted',
            style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey.shade400,
                fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class _FullContent extends StatelessWidget {
  final TaskModel task;
  final int tab;
  final int? daysLeft;
  final bool isOverdue;
  final Color statusColor;
  final String statusLabel;
  final Color priorityColor;

  const _FullContent({
    required this.task,
    required this.tab,
    required this.daysLeft,
    required this.isOverdue,
    required this.statusColor,
    required this.statusLabel,
    required this.priorityColor,
  });

  @override
  Widget build(BuildContext context) {
    final dueDateStr = task.dueDate != null
        ? DateFormat('MMM dd, yyyy').format(task.dueDate!.toLocal())
        : 'No due date';
    final dueDaysStr = daysLeft != null
        ? (daysLeft! < 0
            ? ' (${-daysLeft!}d overdue)'
            : daysLeft == 0
                ? ' (today)'
                : ' (${daysLeft!}d left)')
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(children: [
          Expanded(
            child: Text(task.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
          if (isOverdue) ...[
            const SizedBox(width: 8),
            _MiniChip('OVERDUE', Colors.red),
          ],
          if (task.escalationLevel > 0) ...[
            const SizedBox(width: 4),
            _EscalationBadge(level: task.escalationLevel),
          ],
        ]),
        const SizedBox(height: 7),
        // Badges + meta
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Badge(label: statusLabel, color: statusColor),
            _Badge(
                label: task.priority[0].toUpperCase() +
                    task.priority.substring(1),
                color: priorityColor),
            // Show relevant party per tab
            if (tab == 0 && task.createdByName != null)
              _MetaInfo(
                  icon: Icons.person_add_alt_1_outlined,
                  text: 'by ${task.createdByName!}'),
            if (tab == 1 && task.assignedToName != null)
              _MetaInfo(
                  icon: Icons.person_outline,
                  text: task.assignedToName!),
            if (task.departmentName != null)
              _MetaInfo(
                  icon: Icons.account_tree_outlined,
                  text: task.departmentName!),
          ],
        ),
        const SizedBox(height: 6),
        // Due date row
        Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 12,
              color: isOverdue ? Colors.red.shade400 : Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(
            '$dueDateStr$dueDaysStr',
            style: TextStyle(
                fontSize: 11,
                color: isOverdue ? Colors.red.shade500 : Colors.grey.shade500),
          ),
        ]),
      ],
    );
  }
}

// ── Small shared widgets ──────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  final bool hasMore;
  const _CountBadge(this.count, this.hasMore);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
          color: GemColors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Text(
        hasMore ? '$count+' : '$count',
        style: TextStyle(
            fontSize: 10,
            color: GemColors.green,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _FilterChip(
      {required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? GemColors.green.withValues(alpha: 0.08)
            : Colors.grey.shade100,
        border: Border.all(
            color: active ? GemColors.green : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 14,
            color: active ? GemColors.green : Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: active ? GemColors.green : Colors.grey.shade700,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}

class _ChipDropdown<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T?> onSelected;
  const _ChipDropdown({
    required this.icon,
    required this.label,
    required this.active,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: _FilterChip(icon: icon, label: label, active: active),
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
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _MetaInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.grey.shade500),
      const SizedBox(width: 3),
      Text(text,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          overflow: TextOverflow.ellipsis),
    ]);
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
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warning_amber_rounded, size: 9, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9, color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
