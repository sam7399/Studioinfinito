import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/hr_provider.dart';
import '../../org/providers/org_provider.dart';

class HRPerformancePage extends ConsumerStatefulWidget {
  const HRPerformancePage({super.key});

  @override
  ConsumerState<HRPerformancePage> createState() => _HRPerformancePageState();
}

class _HRPerformancePageState extends ConsumerState<HRPerformancePage> {
  int? _deptFilter;
  String _sortCol = 'name';
  bool _sortAsc = true;

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentsProvider(null)).maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final matrixAsync = ref.watch(hrMatrixProvider(_deptFilter));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HR Performance Matrix',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Employee appraisal metrics — task completion, quality & timeliness',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                // Department filter
                SizedBox(
                  width: 200,
                  child: DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int?>(
                        value: _deptFilter,
                        hint: const Text('All Departments', style: TextStyle(fontSize: 13)),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All Departments', style: TextStyle(fontSize: 13))),
                          ...depts.map((d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.name, style: const TextStyle(fontSize: 13)))),
                        ],
                        onChanged: (v) => setState(() => _deptFilter = v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(hrMatrixProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary chips
            matrixAsync.maybeWhen(
              data: (rows) => _SummaryBar(rows: rows),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),

            // Table
            Expanded(
              child: matrixAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(e.toString()),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => ref.invalidate(hrMatrixProvider), child: const Text('Retry')),
                  ]),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No employees found.'),
                    ]));
                  }
                  final sorted = _sorted(rows);
                  return _MatrixTable(rows: sorted, sortCol: _sortCol, sortAsc: _sortAsc, onSort: _onSort);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<HREmployeeRow> _sorted(List<HREmployeeRow> rows) {
    final list = [...rows];
    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case 'name': cmp = a.name.compareTo(b.name); break;
        case 'dept': cmp = (a.department ?? '').compareTo(b.department ?? ''); break;
        case 'total': cmp = a.totalTasks.compareTo(b.totalTasks); break;
        case 'completed': cmp = a.completedTasks.compareTo(b.completedTasks); break;
        case 'overdue': cmp = a.overdueTasks.compareTo(b.overdueTasks); break;
        case 'rating': cmp = (a.avgRating ?? -1).compareTo(b.avgRating ?? -1); break;
        case 'ontime': cmp = (a.onTimeRate ?? -1).compareTo(b.onTimeRate ?? -1); break;
        default: cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  void _onSort(String col) {
    setState(() {
      if (_sortCol == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = col;
        _sortAsc = true;
      }
    });
  }
}

class _SummaryBar extends StatelessWidget {
  final List<HREmployeeRow> rows;
  const _SummaryBar({required this.rows});

  @override
  Widget build(BuildContext context) {
    final totalEmps = rows.length;
    final totalTasks = rows.fold(0, (s, r) => s + r.totalTasks);
    final totalOverdue = rows.fold(0, (s, r) => s + r.overdueTasks);
    final withReviews = rows.where((r) => r.reviewCount > 0).toList();
    final avgRating = withReviews.isEmpty
        ? null
        : withReviews.fold(0.0, (s, r) => s + (r.avgRating ?? 0)) / withReviews.length;

    return Wrap(spacing: 12, runSpacing: 8, children: [
      _Chip(icon: Icons.people, label: '$totalEmps Employees', color: Colors.indigo),
      _Chip(icon: Icons.task_alt, label: '$totalTasks Total Tasks', color: Colors.blue),
      _Chip(icon: Icons.warning_amber, label: '$totalOverdue Overdue', color: Colors.orange),
      if (avgRating != null)
        _Chip(icon: Icons.star, label: 'Avg Rating ${avgRating.toStringAsFixed(1)}/5', color: Colors.amber.shade700),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _MatrixTable extends StatelessWidget {
  final List<HREmployeeRow> rows;
  final String sortCol;
  final bool sortAsc;
  final void Function(String) onSort;

  const _MatrixTable({required this.rows, required this.sortCol, required this.sortAsc, required this.onSort});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF475569)),
              dataTextStyle: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
              columnSpacing: 20,
              horizontalMargin: 16,
              columns: [
                _col('Employee', 'name'),
                _col('Department', 'dept'),
                _col('Total', 'total'),
                _col('Done', 'completed'),
                _col('Overdue', 'overdue'),
                _col('Rating', 'rating'),
                _col('Quality', 'rating'),
                _col('On-Time %', 'ontime'),
                const DataColumn(label: Text('Reviews')),
              ],
              rows: rows.map((r) => _buildRow(r)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _col(String label, String key) {
    return DataColumn(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label),
        const SizedBox(width: 2),
        if (sortCol == key)
          Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: const Color(0xFF6366F1)),
      ]),
      onSort: (_, __) => onSort(key),
    );
  }

  DataRow _buildRow(HREmployeeRow r) {
    final overdueColor = r.overdueTasks > 0 ? Colors.red.shade700 : Colors.green.shade700;
    return DataRow(cells: [
      // Employee
      DataCell(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (r.designation != null)
            Text(r.designation!, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      )),
      // Department
      DataCell(Text(r.department ?? '—', style: TextStyle(color: Colors.grey.shade600))),
      // Total
      DataCell(Text('${r.totalTasks}', style: const TextStyle(fontWeight: FontWeight.w600))),
      // Completed
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('${r.completedTasks}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
      )),
      // Overdue
      DataCell(r.overdueTasks == 0
          ? Text('0', style: TextStyle(color: Colors.green.shade600))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${r.overdueTasks}', style: TextStyle(color: overdueColor, fontWeight: FontWeight.w700)),
            )),
      // Avg Rating
      DataCell(_ScoreCell(value: r.avgRating, outOf: 5)),
      // Avg Quality
      DataCell(_ScoreCell(value: r.avgQualityScore, outOf: 5)),
      // On-Time %
      DataCell(r.onTimeRate == null
          ? Text('—', style: TextStyle(color: Colors.grey.shade400))
          : _PercentBar(percent: r.onTimeRate!)),
      // Reviews
      DataCell(Text('${r.reviewCount}', style: TextStyle(color: Colors.grey.shade600))),
    ]);
  }
}

class _ScoreCell extends StatelessWidget {
  final double? value;
  final double outOf;
  const _ScoreCell({required this.value, required this.outOf});

  @override
  Widget build(BuildContext context) {
    if (value == null) return Text('—', style: TextStyle(color: Colors.grey.shade400));
    final pct = value! / outOf;
    final color = pct >= 0.8 ? Colors.green.shade700 : pct >= 0.6 ? Colors.orange.shade700 : Colors.red.shade700;
    return Text(
      '${value!.toStringAsFixed(1)}/$outOf',
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _PercentBar extends StatelessWidget {
  final double percent;
  const _PercentBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 80 ? Colors.green.shade700 : percent >= 60 ? Colors.orange.shade700 : Colors.red.shade700;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${percent.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(width: 6),
      SizedBox(
        width: 40,
        height: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
    ]);
  }
}
