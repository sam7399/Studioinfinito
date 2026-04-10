// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../../core/networking/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../org/providers/org_provider.dart';

// ── Safe number helper — handles both int and String from Sequelize ────────────
int _n(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _worklistProvider = FutureProvider.family<Map<String, dynamic>,
    Map<String, dynamic>>((ref, params) async {
  final res = await ref.watch(dioProvider).get(
        ApiConstants.reportWorklist,
        queryParameters: params.isEmpty ? null : params,
      );
  return res.data['data'] as Map<String, dynamic>;
});

final _summaryProvider = FutureProvider.family<Map<String, dynamic>,
    Map<String, dynamic>>((ref, params) async {
  final res = await ref.watch(dioProvider).get(
        ApiConstants.reportSummary,
        queryParameters: params.isEmpty ? null : params,
      );
  return res.data['data'] as Map<String, dynamic>;
});

// ── Models ────────────────────────────────────────────────────────────────────

class _TaskRow {
  final int id;
  final String company;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String assignee;
  final String assigneeEmail;
  final String manager;
  final String department;
  final String location;
  final String raisedBy;
  final String raisedByContact;
  final String createdAt;
  final String dueDate;
  final DateTime? dueDateParsed;

  const _TaskRow({
    required this.id,
    required this.company,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.assignee,
    required this.assigneeEmail,
    required this.manager,
    required this.department,
    required this.location,
    required this.raisedBy,
    required this.raisedByContact,
    required this.createdAt,
    required this.dueDate,
    this.dueDateParsed,
  });

  factory _TaskRow.fromJson(Map<String, dynamic> j) {
    String fmt(String? d) {
      if (d == null || d.isEmpty) return '';
      try {
        return DateFormat('dd MMM yyyy').format(DateTime.parse(d).toLocal());
      } catch (_) {
        return d;
      }
    }

    DateTime? parseDue(String? d) {
      if (d == null || d.isEmpty) return null;
      try {
        return DateTime.parse(d).toLocal();
      } catch (_) {
        return null;
      }
    }

    return _TaskRow(
      id: j['id'] ?? 0,
      company: (j['company'] as Map?)?.get('name') ?? '',
      title: j['title'] ?? '',
      description: j['description'] ?? '',
      priority: j['priority'] ?? '',
      status: j['status'] ?? '',
      assignee: (j['assignee'] as Map?)?.get('name') ?? '',
      assigneeEmail: (j['assignee'] as Map?)?.get('email') ?? '',
      manager: ((j['assignee'] as Map?)?['manager'] as Map?)?.get('name') ?? '',
      department: (j['department'] as Map?)?.get('name') ?? '',
      location: (j['location'] as Map?)?.get('name') ?? '',
      raisedBy: (j['creator'] as Map?)?.get('name') ?? '',
      raisedByContact: (j['creator'] as Map?)?.get('phone') ?? '',
      createdAt: fmt(j['created_at']),
      dueDate: j['due_date'] != null ? fmt(j['due_date']) : '',
      dueDateParsed: parseDue(j['due_date']),
    );
  }
}

extension _MapGet on Map {
  dynamic get(String key) => this[key];
}

// ── Main Page ─────────────────────────────────────────────────────────────────

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Filters
  DateTime? _startDate;
  DateTime? _endDate;
  int? _departmentId;
  int? _locationId;
  int? _companyId;
  int? _userId;
  String? _status;
  String? _priority;
  final _searchCtrl = TextEditingController();

  // Worklist pagination
  int _page = 1;
  int _limit = 20;
  String _sortBy = 'created_at';
  bool _sortAsc = false;
  String? _worklistStatus; // null=all, status value, or 'overdue'

  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _filterParams {
    final p = <String, dynamic>{};
    if (_startDate != null) p['start_date'] = DateFormat('yyyy-MM-dd').format(_startDate!);
    if (_endDate != null) p['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
    if (_status != null) p['status'] = _status;
    if (_priority != null) p['priority'] = _priority;
    if (_userId != null) p['user_id'] = _userId;
    if (_companyId != null) p['company_id'] = _companyId;
    if (_departmentId != null) p['department_id'] = _departmentId;
    if (_locationId != null) p['location_id'] = _locationId;
    if (_searchCtrl.text.isNotEmpty) p['search'] = _searchCtrl.text;
    return p;
  }

  Map<String, dynamic> get _worklistParams {
    final p = <String, dynamic>{
      ..._filterParams,
      'page': _page,
      'limit': _limit,
      'sort_by': _sortBy,
      'sort_order': _sortAsc ? 'asc' : 'desc',
    };
    if (_worklistStatus == 'overdue') {
      p.remove('status');
      p['overdue'] = 'true';
    } else if (_worklistStatus != null) {
      p['status'] = _worklistStatus;
    }
    return p;
  }

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now().subtract(const Duration(days: 30)))
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => isStart ? _startDate = d : _endDate = d);
  }

  void _clearFilters() => setState(() {
        _startDate = null;
        _endDate = null;
        _departmentId = null;
        _locationId = null;
        _companyId = null;
        _userId = null;
        _status = null;
        _priority = null;
        _worklistStatus = null;
        _searchCtrl.clear();
        _page = 1;
      });

  bool get _hasFilters =>
      _startDate != null ||
      _endDate != null ||
      _departmentId != null ||
      _locationId != null ||
      _companyId != null ||
      _userId != null ||
      _status != null ||
      _priority != null ||
      _searchCtrl.text.isNotEmpty;

  Future<void> _downloadExcel(String groupBy) async {
    try {
      final dio = ref.read(dioProvider);
      final params = Map<String, dynamic>.from(_filterParams)
        ..['group_by'] = groupBy;
      final response = await dio.get<List<int>>(
        ApiConstants.reportExcelExport,
        queryParameters: params,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data ?? [];
      final blob = html.Blob(
        [bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
            'download',
            'task_report_${groupBy}_${DateTime.now().millisecondsSinceEpoch}.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showExcelDialog() {
    String selected = 'status';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Widget optionTile(String id, IconData icon, Color color, String title, String desc) {
            final isSelected = selected == id;
            return GestureDetector(
              onTap: () => setDlgState(() => selected = id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.07) : Colors.grey.shade50,
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? color : Colors.black87)),
                          const SizedBox(height: 2),
                          Text(desc,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSelected ? color : Colors.grey.shade400,
                            width: 2),
                        color: isSelected ? color : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 11, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.download_outlined,
                              color: Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Download Excel Report',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('Choose how to organise the sheets',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    optionTile('status',     Icons.label_outline,       const Color(0xFF8B5CF6), 'By Status',
                        'Separate sheet per status — Open, In Progress, Pending Review, Finalized, Reopened, Overdue.'),
                    optionTile('department', Icons.business_outlined,   const Color(0xFF3B82F6), 'By Department',
                        'One sheet per department showing all its tasks.'),
                    optionTile('location',   Icons.location_on_outlined, const Color(0xFF10B981), 'By Location',
                        'One sheet per office / branch location with its task list.'),
                    optionTile('user',       Icons.person_outline,      const Color(0xFFF59E0B), 'By Team Member',
                        'One sheet per assigned user — perfect for workload reviews.'),
                    optionTile('company',    Icons.domain_outlined,     const Color(0xFFEC4899), 'By Company',
                        'One sheet per company (superadmin cross-company reports).'),
                    optionTile('full',       Icons.layers_outlined,     const Color(0xFFEF4444), 'Full Report',
                        'All Tasks + Status / Dept / Location / User / Company summary tables.'),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981)),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Download'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _downloadExcel(selected);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _printPage() => html.window.print();

  void _showEmailDialog() {
    showDialog(
      context: context,
      builder: (_) => _EmailDialog(
        filters: _filterParams,
        onSent: (msg) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider)
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final depts = ref.watch(departmentsProvider(_companyId))
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final locs = ref.watch(locationsProvider(_companyId))
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final users = ref.watch(allUsersProvider)
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reports & Analytics',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text('User · Location · Department · Company reports',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    // Action buttons
                    _ActionBtn(
                      icon: Icons.mail_outline,
                      label: 'Email',
                      color: const Color(0xFF8B5CF6),
                      onTap: _showEmailDialog,
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.download_outlined,
                      label: 'Excel',
                      color: const Color(0xFF10B981),
                      onTap: _showExcelDialog,
                    ),
                    const SizedBox(width: 8),
                    _ActionBtn(
                      icon: Icons.print_outlined,
                      label: 'Print',
                      color: const Color(0xFF3B82F6),
                      onTap: _printPage,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Filter bar ─────────────────────────────────────
                _FilterBar(
                  expanded: _filtersExpanded,
                  hasFilters: _hasFilters,
                  startDate: _startDate,
                  endDate: _endDate,
                  status: _status,
                  priority: _priority,
                  searchCtrl: _searchCtrl,
                  companies: companies,
                  depts: depts,
                  locs: locs,
                  users: users,
                  companyId: _companyId,
                  departmentId: _departmentId,
                  locationId: _locationId,
                  userId: _userId,
                  onToggleExpand: () =>
                      setState(() => _filtersExpanded = !_filtersExpanded),
                  onPickDate: _pickDate,
                  onStatusChanged: (v) => setState(() {
                    _status = v;
                    _page = 1;
                  }),
                  onPriorityChanged: (v) => setState(() {
                    _priority = v;
                    _page = 1;
                  }),
                  onCompanyChanged: (v) => setState(() {
                    _companyId = v;
                    _departmentId = null;
                    _locationId = null;
                    _page = 1;
                  }),
                  onDeptChanged: (v) => setState(() {
                    _departmentId = v;
                    _page = 1;
                  }),
                  onLocChanged: (v) => setState(() {
                    _locationId = v;
                    _page = 1;
                  }),
                  onUserChanged: (v) => setState(() {
                    _userId = v;
                    _page = 1;
                  }),
                  onSearch: () => setState(() => _page = 1),
                  onClear: _clearFilters,
                ),
                const SizedBox(height: 8),

                // ── Tab bar ────────────────────────────────────────
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Task Worklist'),
                    Tab(text: 'By User'),
                    Tab(text: 'By Department'),
                    Tab(text: 'By Company / Location'),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab Views ──────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // Overview
                _OverviewTab(params: _filterParams),
                // Worklist
                _WorklistTab(
                  params: _worklistParams,
                  filterParams: _filterParams,
                  page: _page,
                  limit: _limit,
                  sortBy: _sortBy,
                  sortAsc: _sortAsc,
                  worklistStatus: _worklistStatus,
                  onPageChanged: (p) => setState(() => _page = p),
                  onLimitChanged: (l) => setState(() {
                    _limit = l;
                    _page = 1;
                  }),
                  onSort: (col, asc) => setState(() {
                    _sortBy = col;
                    _sortAsc = asc;
                    _page = 1;
                  }),
                  onWorklistStatusChanged: (s) => setState(() {
                    _worklistStatus = s;
                    _page = 1;
                  }),
                ),
                // By User
                _SummaryTab(
                    params: _filterParams, groupKey: 'byUser'),
                // By Department
                _SummaryTab(
                    params: _filterParams, groupKey: 'byDepartment'),
                // By Company / Location
                _CompanyLocationTab(params: _filterParams),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final bool expanded;
  final bool hasFilters;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? priority;
  final TextEditingController searchCtrl;
  final List<OrgItem> companies;
  final List<OrgItem> depts;
  final List<OrgItem> locs;
  final List<OrgItem> users;
  final int? companyId;
  final int? departmentId;
  final int? locationId;
  final int? userId;
  final VoidCallback onToggleExpand;
  final void Function(bool) onPickDate;
  final void Function(String?) onStatusChanged;
  final void Function(String?) onPriorityChanged;
  final void Function(int?) onCompanyChanged;
  final void Function(int?) onDeptChanged;
  final void Function(int?) onLocChanged;
  final void Function(int?) onUserChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _FilterBar({
    required this.expanded,
    required this.hasFilters,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.priority,
    required this.searchCtrl,
    required this.companies,
    required this.depts,
    required this.locs,
    required this.users,
    required this.companyId,
    required this.departmentId,
    required this.locationId,
    required this.userId,
    required this.onToggleExpand,
    required this.onPickDate,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCompanyChanged,
    required this.onDeptChanged,
    required this.onLocChanged,
    required this.onUserChanged,
    required this.onSearch,
    required this.onClear,
  });

  String _fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: search + date + toggle
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            searchCtrl.clear();
                            onSearch();
                          })
                      : null,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 14),
              label: Text(
                startDate != null ? _fmt(startDate!) : 'From',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => onPickDate(true),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10)),
            ),
            const SizedBox(width: 4),
            const Text('–', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 4),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 14),
              label: Text(
                endDate != null ? _fmt(endDate!) : 'To',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => onPickDate(false),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: Icon(
                  expanded ? Icons.filter_list_off : Icons.filter_list,
                  size: 16),
              label: Text(expanded ? 'Hide Filters' : 'More Filters',
                  style: const TextStyle(fontSize: 12)),
              onPressed: onToggleExpand,
            ),
            if (hasFilters) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
                onPressed: onClear,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          // Row 2: advanced filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Status
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  value: status,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In Progress')),
                    DropdownMenuItem(
                        value: 'complete_pending_review',
                        child: Text('Pending Review')),
                    DropdownMenuItem(
                        value: 'finalized', child: Text('Finalized')),
                    DropdownMenuItem(
                        value: 'reopened', child: Text('Reopened')),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
              // Priority
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String?>(
                  value: priority,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: null, child: Text('All Priority')),
                    DropdownMenuItem(
                        value: 'urgent', child: Text('Urgent')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(
                        value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                  ],
                  onChanged: onPriorityChanged,
                ),
              ),
              // Company
              if (companies.isNotEmpty)
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int?>(
                    value: companyId,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Companies')),
                      ...companies.map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.name))),
                    ],
                    onChanged: onCompanyChanged,
                  ),
                ),
              // Department
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int?>(
                  value: departmentId,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Departments')),
                    ...depts.map((d) => DropdownMenuItem(
                        value: d.id,
                        child:
                            Text(d.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: onDeptChanged,
                ),
              ),
              // Location
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int?>(
                  value: locationId,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Locations')),
                    ...locs.map((l) => DropdownMenuItem(
                        value: l.id,
                        child:
                            Text(l.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: onLocChanged,
                ),
              ),
              // User
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int?>(
                  value: userId,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assigned To',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Users')),
                    ...users.map((u) => DropdownMenuItem(
                        value: u.id,
                        child:
                            Text(u.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: onUserChanged,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  final Map<String, dynamic> params;
  const _OverviewTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worklistAsync = ref.watch(_worklistProvider({...params, 'limit': 1}));
    final summaryAsync = ref.watch(_summaryProvider(params));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats from worklist total
          worklistAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => const SizedBox.shrink(),
            data: (d) {
              final total = _n(d['pagination']?['total']);
              return _StatRow(total: total, params: params);
            },
          ),
          const SizedBox(height: 24),

          // Summary charts
          summaryAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('Error: $e', style: const TextStyle(color: Colors.red)),
            data: (data) => Column(
              children: [
                LayoutBuilder(builder: (_, c) {
                  final wide = c.maxWidth > 700;
                  final byUser = data['byUser'] as List? ?? [];
                  final byDept = data['byDepartment'] as List? ?? [];
                  final charts = [
                    _PieChartCard(
                      title: 'Tasks by Department',
                      items: byDept
                          .take(8)
                          .map((d) => _PieItem(
                                label: (d['department'] as Map?)
                                        ?['name'] as String? ??
                                    'Unknown',
                                value: _n(d['total']),
                              ))
                          .toList(),
                    ),
                    _BarChartCard(
                      title: 'Top Users by Workload',
                      items: byUser
                          .take(8)
                          .map((d) => _BarItem(
                                label: (d['assignee'] as Map?)
                                        ?['name'] as String? ??
                                    'Unknown',
                                open: _n(d['open']),
                                inProgress: _n(d['in_progress']),
                                overdue: _n(d['overdue']),
                              ))
                          .toList(),
                    ),
                  ];
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: charts[0]),
                        const SizedBox(width: 16),
                        Expanded(child: charts[1]),
                      ],
                    );
                  }
                  return Column(children: [
                    charts[0],
                    const SizedBox(height: 16),
                    charts[1]
                  ]);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Worklist Tab ──────────────────────────────────────────────────────────────

class _WorklistTab extends ConsumerWidget {
  final Map<String, dynamic> params;
  final Map<String, dynamic> filterParams;
  final int page;
  final int limit;
  final String sortBy;
  final bool sortAsc;
  final String? worklistStatus;
  final void Function(int) onPageChanged;
  final void Function(int) onLimitChanged;
  final void Function(String, bool) onSort;
  final void Function(String?) onWorklistStatusChanged;

  const _WorklistTab({
    required this.params,
    required this.filterParams,
    required this.page,
    required this.limit,
    required this.sortBy,
    required this.sortAsc,
    required this.worklistStatus,
    required this.onPageChanged,
    required this.onLimitChanged,
    required this.onSort,
    required this.onWorklistStatusChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_worklistProvider(params));

    // Status quick-filter tab definitions
    final tabs = <(String label, String? status, Color color)>[
      ('All Tasks', null, const Color(0xFF64748B)),
      ('Open', 'open', const Color(0xFFF59E0B)),
      ('In Progress', 'in_progress', const Color(0xFF8B5CF6)),
      ('Pending Review', 'complete_pending_review', const Color(0xFFF97316)),
      ('Finalized', 'finalized', const Color(0xFF10B981)),
      ('Reopened', 'reopened', const Color(0xFFEC4899)),
      ('Overdue', 'overdue', const Color(0xFFEF4444)),
    ];

    return Column(
      children: [
        // ── Quick Status Filter Tabs ────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.map((tab) {
                final isActive = worklistStatus == tab.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 10),
                  child: InkWell(
                    onTap: () => onWorklistStatusChanged(tab.$2),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? tab.$3
                            : tab.$3.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? tab.$3
                              : tab.$3.withValues(alpha: 0.3),
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        tab.$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isActive ? Colors.white : tab.$3,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),

        // ── Table + Pagination ──────────────────────────────────────────
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: Colors.red))),
            data: (data) {
              final tasks = (data['tasks'] as List? ?? [])
                  .map((j) => _TaskRow.fromJson(j as Map<String, dynamic>))
                  .toList();
              final pagination =
                  data['pagination'] as Map<String, dynamic>? ?? {};
              final total = _n(pagination['total']);
              final pages = _n(pagination['pages']).clamp(1, 999999);

              return Column(
                children: [
                  // Task count banner
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Row(children: [
                      Icon(Icons.list_alt_outlined,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        '$total task${total == 1 ? '' : 's'} found',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _TaskTable(
                        tasks: tasks,
                        sortBy: sortBy,
                        sortAsc: sortAsc,
                        onSort: onSort,
                      ),
                    ),
                  ),
                  _PaginationBar(
                    page: page,
                    pages: pages,
                    limit: limit,
                    total: total,
                    onPageChanged: onPageChanged,
                    onLimitChanged: onLimitChanged,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Task Table ────────────────────────────────────────────────────────────────

class _TaskTable extends StatelessWidget {
  final List<_TaskRow> tasks;
  final String sortBy;
  final bool sortAsc;
  final void Function(String, bool) onSort;

  const _TaskTable({
    required this.tasks,
    required this.sortBy,
    required this.sortAsc,
    required this.onSort,
  });

  Color _priorityColor(String p) => switch (p) {
        'urgent' => const Color(0xFFEF4444),
        'high' => const Color(0xFFF97316),
        'normal' => const Color(0xFF3B82F6),
        _ => Colors.grey,
      };

  Color _statusColor(String s) => switch (s) {
        'open' => const Color(0xFFF59E0B),
        'in_progress' => const Color(0xFF8B5CF6),
        'complete_pending_review' => const Color(0xFFF97316),
        'finalized' => const Color(0xFF10B981),
        'reopened' => const Color(0xFFEF4444),
        _ => Colors.grey,
      };

  String _statusLabel(String s) => switch (s) {
        'open' => 'Open',
        'in_progress' => 'In Progress',
        'complete_pending_review' => 'Pending Review',
        'finalized' => 'Finalized',
        'reopened' => 'Reopened',
        _ => s,
      };

  Widget _sortHeader(String col, String label) {
    final active = sortBy == col;
    return InkWell(
      onTap: () => onSort(col, active ? !sortAsc : false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: active
                      ? const Color(0xFF3B82F6)
                      : Colors.grey.shade700)),
          const SizedBox(width: 2),
          Icon(
            active
                ? (sortAsc ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 12,
            color:
                active ? const Color(0xFF3B82F6) : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Text('No tasks found for the selected filters',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
          headingTextStyle: const TextStyle(color: Colors.white),
          dataRowMinHeight: 44,
          dataRowMaxHeight: 60,
          columnSpacing: 16,
          columns: [
            DataColumn(label: _sortHeader('title', '#  Task Title')),
            DataColumn(label: Text('Company', style: _headerStyle)),
            DataColumn(label: _sortHeader('priority', 'Priority')),
            DataColumn(label: _sortHeader('status', 'Status')),
            DataColumn(label: Text('Assigned To', style: _headerStyle)),
            DataColumn(label: Text('Manager', style: _headerStyle)),
            DataColumn(label: Text('Department', style: _headerStyle)),
            DataColumn(label: Text('Location', style: _headerStyle)),
            DataColumn(label: Text('Raised By', style: _headerStyle)),
            DataColumn(label: Text('Contact', style: _headerStyle)),
            DataColumn(label: _sortHeader('created_at', 'Created')),
            DataColumn(label: _sortHeader('due_date', 'Due Date')),
          ],
          rows: tasks.map((t) {
            final isOverdue = t.dueDateParsed != null &&
                t.status != 'finalized' &&
                t.dueDateParsed!.isBefore(DateTime.now());
            return DataRow(
              color: isOverdue
                  ? WidgetStateProperty.all(Colors.red.shade50)
                  : null,
              cells: [
                DataCell(SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${t.id}. ${t.title}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
                DataCell(Text(t.company,
                    style: const TextStyle(fontSize: 12))),
                DataCell(_Badge(
                    t.priority.toUpperCase(),
                    _priorityColor(t.priority))),
                DataCell(_Badge(
                    _statusLabel(t.status),
                    _statusColor(t.status))),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.assignee,
                        style: const TextStyle(fontSize: 12)),
                    if (t.assigneeEmail.isNotEmpty)
                      Text(t.assigneeEmail,
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                  ],
                )),
                DataCell(Text(t.manager,
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(t.department,
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(t.location,
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(t.raisedBy,
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(t.raisedByContact,
                    style: const TextStyle(fontSize: 12))),
                DataCell(Text(t.createdAt,
                    style: const TextStyle(fontSize: 12))),
                DataCell(_DueDateCell(
                  dateStr: t.dueDate,
                  dateParsed: t.dueDateParsed,
                  isFinalized: t.status == 'finalized',
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  TextStyle get _headerStyle =>
      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
}

// ── Pagination Bar ────────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int page;
  final int pages;
  final int limit;
  final int total;
  final void Function(int) onPageChanged;
  final void Function(int) onLimitChanged;

  const _PaginationBar({
    required this.page,
    required this.pages,
    required this.limit,
    required this.total,
    required this.onPageChanged,
    required this.onLimitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final from = ((page - 1) * limit) + 1;
    final to = (page * limit).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Text('Show: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          DropdownButton<int>(
            value: limit,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: [10, 20, 50, 100]
                .map((n) => DropdownMenuItem(
                    value: n,
                    child: Text('$n', style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) => onLimitChanged(v!),
          ),
          const SizedBox(width: 16),
          Text('$from–$to of $total',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.first_page, size: 18),
            onPressed: page > 1 ? () => onPageChanged(1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            onPressed:
                page > 1 ? () => onPageChanged(page - 1) : null,
          ),
          Text('$page / $pages',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            onPressed:
                page < pages ? () => onPageChanged(page + 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page, size: 18),
            onPressed:
                page < pages ? () => onPageChanged(pages) : null,
          ),
        ],
      ),
    );
  }
}

// ── Summary Tab (By User / By Department) ─────────────────────────────────────

class _SummaryTab extends ConsumerWidget {
  final Map<String, dynamic> params;
  final String groupKey;
  const _SummaryTab({required this.params, required this.groupKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_summaryProvider(params));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      data: (data) {
        final rows = data[groupKey] as List? ?? [];
        if (rows.isEmpty) {
          return const Center(
              child: Text('No data for selected filters',
                  style: TextStyle(color: Colors.grey)));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _SummaryTable(rows: rows, groupKey: groupKey),
        );
      },
    );
  }
}

class _SummaryTable extends StatelessWidget {
  final List rows;
  final String groupKey;
  const _SummaryTable({required this.rows, required this.groupKey});

  String _groupLabel(Map r) {
    if (groupKey == 'byUser') {
      return (r['assignee'] as Map?)?['name'] as String? ?? 'Unknown';
    }
    if (groupKey == 'byDepartment') {
      final dept = (r['department'] as Map?)?['name'] as String? ?? '';
      final company = ((r['department'] as Map?)?['company'] as Map?)?['name'] as String? ?? '';
      return company.isNotEmpty ? '$dept ($company)' : dept;
    }
    return '—';
  }

  String _subLabel(Map r) {
    if (groupKey == 'byUser') {
      final mgr = ((r['assignee'] as Map?)?['manager'] as Map?)?['name'] as String?;
      final desig = (r['assignee'] as Map?)?['designation'] as String?;
      return [desig, mgr != null ? 'Mgr: $mgr' : null]
          .where((s) => s != null)
          .join(' · ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
        headingTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
        columnSpacing: 20,
        columns: [
          DataColumn(
              label: Text(
                  groupKey == 'byUser' ? 'User' : 'Department',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: const Text('Open',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: const Text('In Progress',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: const Text('Pending Review',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: const Text('Finalized',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: const Text('Overdue',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444))),
              numeric: true),
        ],
        rows: rows.map<DataRow>((r) {
          final overdue = _n((r as Map)['overdue']);
          final sub = _subLabel(r);
          return DataRow(cells: [
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_groupLabel(r),
                    style: const TextStyle(fontWeight: FontWeight.w500,
                        fontSize: 13)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500)),
              ],
            )),
            DataCell(_NumCell(_n(r['total']), null)),
            DataCell(_NumCell(_n(r['open']), const Color(0xFFF59E0B))),
            DataCell(_NumCell(_n(r['in_progress']), const Color(0xFF8B5CF6))),
            DataCell(_NumCell(_n(r['pending_review']), const Color(0xFFF97316))),
            DataCell(_NumCell(_n(r['finalized']), const Color(0xFF10B981))),
            DataCell(_NumCell(
                overdue,
                overdue > 0 ? const Color(0xFFEF4444) : Colors.grey)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Company / Location Tab ────────────────────────────────────────────────────

class _CompanyLocationTab extends ConsumerWidget {
  final Map<String, dynamic> params;
  const _CompanyLocationTab({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_summaryProvider(params));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      data: (data) {
        final byCompany = data['byCompany'] as List? ?? [];
        final byLocation = data['byLocation'] as List? ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('By Company',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _SimpleGroupTable(
                rows: byCompany,
                nameExtractor: (r) =>
                    (r['company'] as Map?)?['name'] as String? ?? 'Unknown',
              ),
              const SizedBox(height: 24),
              const Text('By Location',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _SimpleGroupTable(
                rows: byLocation,
                nameExtractor: (r) =>
                    (r['location'] as Map?)?['name'] as String? ?? 'Unknown',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SimpleGroupTable extends StatelessWidget {
  final List rows;
  final String Function(Map) nameExtractor;
  const _SimpleGroupTable(
      {required this.rows, required this.nameExtractor});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No data', style: TextStyle(color: Colors.grey));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
        headingTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
        columnSpacing: 24,
        columns: const [
          DataColumn(
              label: Text('Name',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Total',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: Text('Open',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: Text('In Progress',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: Text('Finalized',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true),
          DataColumn(
              label: Text('Overdue',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444))),
              numeric: true),
        ],
        rows: rows.map<DataRow>((r) {
          final rm = r as Map;
          final overdue = _n(rm['overdue']);
          return DataRow(cells: [
            DataCell(Text(nameExtractor(rm),
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13))),
            DataCell(_NumCell(_n(rm['total']), null)),
            DataCell(_NumCell(_n(rm['open']), const Color(0xFFF59E0B))),
            DataCell(_NumCell(_n(rm['in_progress']), const Color(0xFF8B5CF6))),
            DataCell(_NumCell(_n(rm['finalized']), const Color(0xFF10B981))),
            DataCell(_NumCell(
                overdue,
                overdue > 0 ? const Color(0xFFEF4444) : Colors.grey)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Overview Stat Row ─────────────────────────────────────────────────────────

class _StatRow extends ConsumerWidget {
  final int total;
  final Map<String, dynamic> params;
  const _StatRow({required this.total, required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_summaryProvider(params));

    Widget buildCards(int open, int inProgress, int pending, int finalized,
        int overdue) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            _StatCard('Total Tasks', '$total', const Color(0xFF3B82F6),
                Icons.task_alt_outlined),
            _StatCard('Open', '$open', const Color(0xFFF59E0B),
                Icons.inbox_outlined),
            _StatCard('In Progress', '$inProgress', const Color(0xFF8B5CF6),
                Icons.pending_actions_outlined),
            _StatCard('Pending Review', '$pending', const Color(0xFFF97316),
                Icons.rate_review_outlined),
            _StatCard('Finalized', '$finalized', const Color(0xFF10B981),
                Icons.check_circle_outline),
            _StatCard('Overdue', '$overdue', const Color(0xFFEF4444),
                Icons.warning_amber_outlined),
          ],
        ),
      );
    }

    return summaryAsync.when(
      loading: () => buildCards(0, 0, 0, 0, 0),
      error: (_, __) => buildCards(0, 0, 0, 0, 0),
      data: (data) {
        int open = 0, inProgress = 0, pending = 0, finalized = 0, overdue = 0;
        for (final u in (data['byUser'] as List? ?? [])) {
          final m = u as Map;
          open += _n(m['open']);
          inProgress += _n(m['in_progress']);
          pending += _n(m['pending_review']);
          finalized += _n(m['finalized']);
          overdue += _n(m['overdue']);
        }
        return buildCards(open, inProgress, pending, finalized, overdue);
      },
    );
  }
}

// ── Charts ────────────────────────────────────────────────────────────────────

class _PieItem {
  final String label;
  final int value;
  const _PieItem({required this.label, required this.value});
}

class _BarItem {
  final String label;
  final int open;
  final int inProgress;
  final int overdue;
  const _BarItem(
      {required this.label,
      required this.open,
      required this.inProgress,
      required this.overdue});
}

final _pieColors = [
  const Color(0xFF3B82F6),
  const Color(0xFF10B981),
  const Color(0xFF8B5CF6),
  const Color(0xFFF59E0B),
  const Color(0xFFEF4444),
  const Color(0xFFF97316),
  const Color(0xFF0D9488),
  const Color(0xFF6366F1),
];

class _PieChartCard extends StatelessWidget {
  final String title;
  final List<_PieItem> items;
  const _PieChartCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (s, i) => s + i.value);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          if (total == 0)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child:
                  Text('No data', style: TextStyle(color: Colors.grey)),
            ))
          else
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(PieChartData(
                      sections: items.asMap().entries.map((e) {
                        final pct = e.value.value / total * 100;
                        return PieChartSectionData(
                          value: e.value.value.toDouble(),
                          color: _pieColors[e.key % _pieColors.length],
                          radius: 55,
                          title: pct >= 5 ? '${pct.round()}%' : '',
                          titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                    )),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: _pieColors[
                                        e.key % _pieColors.length],
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              e.value.label.length > 14
                                  ? '${e.value.label.substring(0, 14)}…'
                                  : e.value.label,
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            Text('${e.value.value}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  final String title;
  final List<_BarItem> items;
  const _BarChartCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            const Center(
                child: Text('No data', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    final maxVal = items
        .map((i) => i.open + i.inProgress + i.overdue)
        .fold<int>(0, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          // Legend
          Row(
            children: [
              _LegendDot('Open', const Color(0xFFF59E0B)),
              const SizedBox(width: 12),
              _LegendDot('In Progress', const Color(0xFF8B5CF6)),
              const SizedBox(width: 12),
              _LegendDot('Overdue', const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: BarChart(BarChartData(
              maxY: (maxVal + 2).toDouble(),
              gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 10 ? (maxVal / 5).toDouble() : 2),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx >= items.length) return const SizedBox.shrink();
                      final name = items[idx].label;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          name.length > 6 ? name.substring(0, 6) : name,
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}',
                            style: const TextStyle(fontSize: 9)))),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: items.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: (e.value.open + e.value.inProgress +
                              e.value.overdue)
                          .toDouble(),
                      width: 16,
                      borderRadius: BorderRadius.circular(4),
                      rodStackItems: [
                        BarChartRodStackItem(
                            0,
                            e.value.open.toDouble(),
                            const Color(0xFFF59E0B)),
                        BarChartRodStackItem(
                            e.value.open.toDouble(),
                            (e.value.open + e.value.inProgress)
                                .toDouble(),
                            const Color(0xFF8B5CF6)),
                        BarChartRodStackItem(
                            (e.value.open + e.value.inProgress)
                                .toDouble(),
                            (e.value.open +
                                    e.value.inProgress +
                                    e.value.overdue)
                                .toDouble(),
                            const Color(0xFFEF4444)),
                      ],
                    ),
                  ],
                );
              }).toList(),
            )),
          ),
        ],
      ),
    );
  }
}

// ── Email Dialog ──────────────────────────────────────────────────────────────

class _EmailDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> filters;
  final void Function(String) onSent;
  const _EmailDialog({required this.filters, required this.onSent});

  @override
  ConsumerState<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends ConsumerState<_EmailDialog> {
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController(
      text: 'Task Report - ${DateFormat('dd MMM yyyy').format(DateTime.now())}');
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_emailCtrl.text.isEmpty || !_emailCtrl.text.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(ApiConstants.reportEmail, data: {
        'recipient_email': _emailCtrl.text.trim(),
        'subject': _subjectCtrl.text.trim(),
        'filters': widget.filters,
      });
      widget.onSent('Report sent to ${_emailCtrl.text.trim()}');
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message'] ?? 'Failed to send email';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.mail_outline, color: Color(0xFF8B5CF6)),
          SizedBox(width: 8),
          Text('Email Report'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Recipient Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A CSV report with current filters will be sent as attachment. Use the Excel download button for a multi-sheet workbook.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade700, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton.icon(
          icon: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 16),
          label: Text(_sending ? 'Sending...' : 'Send Report'),
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}

// ── Due Date Cell with Days-Remaining Indicator ───────────────────────────────

class _DueDateCell extends StatelessWidget {
  final String dateStr;
  final DateTime? dateParsed;
  final bool isFinalized;

  const _DueDateCell({
    required this.dateStr,
    required this.dateParsed,
    required this.isFinalized,
  });

  @override
  Widget build(BuildContext context) {
    if (dateStr.isEmpty) {
      return const Text('—', style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    final now = DateTime.now();
    final isOverdue =
        dateParsed != null && !isFinalized && dateParsed!.isBefore(now);
    final diff = dateParsed != null ? dateParsed!.difference(now).inDays : null;

    Color chipColor;
    String chipLabel;

    if (isOverdue) {
      chipColor = const Color(0xFFEF4444);
      chipLabel = '${(diff ?? 0).abs()}d overdue';
    } else if (diff != null && diff == 0) {
      chipColor = const Color(0xFFF97316);
      chipLabel = 'Due today';
    } else if (diff != null && diff <= 3) {
      chipColor = const Color(0xFFF97316);
      chipLabel = '${diff}d left';
    } else if (diff != null && diff <= 7) {
      chipColor = const Color(0xFFF59E0B);
      chipLabel = '${diff}d left';
    } else if (isFinalized) {
      chipColor = const Color(0xFF10B981);
      chipLabel = 'Done';
    } else {
      chipColor = const Color(0xFF10B981);
      chipLabel = diff != null ? '${diff}d left' : '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          dateStr,
          style: TextStyle(
            fontSize: 12,
            color: isOverdue ? const Color(0xFFEF4444) : null,
            fontWeight: isOverdue ? FontWeight.bold : null,
          ),
        ),
        if (chipLabel.isNotEmpty) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              chipLabel,
              style: TextStyle(
                fontSize: 9,
                color: chipColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Small helper widgets ──────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 14, color: color),
      label: Text(label,
          style: TextStyle(color: color, fontSize: 12)),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _NumCell extends StatelessWidget {
  final int value;
  final Color? color;
  const _NumCell(this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      '$value',
      style: TextStyle(
          fontSize: 13,
          fontWeight: value > 0 ? FontWeight.bold : FontWeight.normal,
          color: value > 0 ? (color ?? Colors.black87) : Colors.grey),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }
}

