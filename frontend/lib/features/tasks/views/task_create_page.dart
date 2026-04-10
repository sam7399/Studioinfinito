import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/dio_client.dart';
import '../providers/task_provider.dart';
import '../../org/providers/org_provider.dart';
import 'attachment_section.dart';

// userId → active task count for workload dot
final _workloadSingleProvider = FutureProvider.autoDispose<Map<int, int>>((ref) async {
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

Color _wColor(int n) {
  if (n <= 3) return const Color(0xFF16A34A);
  if (n <= 6) return const Color(0xFFD97706);
  return const Color(0xFFDC2626);
}

String _wLabel(int n) {
  if (n == 0) return 'Free';
  if (n <= 3) return '$n active – Light';
  if (n <= 6) return '$n active – Moderate';
  return '$n active – Heavy';
}

class TaskCreatePage extends ConsumerStatefulWidget {
  const TaskCreatePage({super.key});

  @override
  ConsumerState<TaskCreatePage> createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends ConsumerState<TaskCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _priority = 'normal';
  int? _assignedTo;
  int? _departmentId;
  int? _locationId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  bool _showCollaborators = true;
  bool _loading = false;
  String? _error;
  final List<PendingAttachment> _attachments = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'priority': _priority,
      'assigned_to': _assignedTo,
      'department_id': _departmentId,
      'location_id': _locationId,
      'due_date': _dueDate.toIso8601String(),
      'show_collaborators': _showCollaborators,
    };

    try {
      final taskId = await ref.read(taskProvider.notifier).createTask(data);
      if (_attachments.isNotEmpty) {
        await uploadPendingAttachments(ref, taskId, _attachments);
      }
      if (mounted) context.go('/tasks');
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final users = usersAsync.maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final usersLoading = usersAsync.isLoading;
    final depts = ref.watch(departmentsProvider(null)).maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final locs = ref.watch(locationsProvider(null)).maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final workload = ref.watch(_workloadSingleProvider).maybeWhen(data: (d) => d, orElse: () => <int, int>{});

    final selectedUserWorkload = _assignedTo != null ? (workload[_assignedTo] ?? 0) : -1;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: () => context.go('/tasks'),
                    icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 8),
                Text('Create Task',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              constraints: const BoxConstraints(maxWidth: 700),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8)
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Title *',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),

                    // Priority
                    DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder()),
                      items: ['low', 'normal', 'high', 'urgent']
                          .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                  p[0].toUpperCase() + p.substring(1))))
                          .toList(),
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                    const SizedBox(height: 16),

                    // Assign To + workload indicator
                    DropdownButtonFormField<int>(
                      value: _assignedTo,
                      decoration: InputDecoration(
                          labelText: usersLoading ? 'Loading users...' : 'Assign To *',
                          border: const OutlineInputBorder()),
                      isExpanded: true,
                      items: users.map((u) {
                        final count = workload[u.id] ?? 0;
                        final color = _wColor(count);
                        return DropdownMenuItem(
                          value: u.id,
                          child: Row(children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            Expanded(child: Text(u.name, overflow: TextOverflow.ellipsis)),
                            Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _assignedTo = v),
                      validator: (v) => v == null ? 'Please select a user' : null,
                    ),

                    // Workload info banner when user selected
                    if (selectedUserWorkload >= 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _wColor(selectedUserWorkload).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _wColor(selectedUserWorkload).withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: _wColor(selectedUserWorkload), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _wLabel(selectedUserWorkload),
                            style: TextStyle(fontSize: 12, color: _wColor(selectedUserWorkload), fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Department & Location
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _departmentId,
                            decoration: const InputDecoration(
                                labelText: 'Department *',
                                border: OutlineInputBorder()),
                            isExpanded: true,
                            items: depts
                                .map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.name,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _departmentId = v),
                            validator: (v) =>
                                v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _locationId,
                            decoration: const InputDecoration(
                                labelText: 'Location *',
                                border: OutlineInputBorder()),
                            isExpanded: true,
                            items: locs
                                .map((l) => DropdownMenuItem(
                                    value: l.id,
                                    child: Text(l.name,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _locationId = v),
                            validator: (v) =>
                                v == null ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Due Date
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                          'Due Date: ${DateFormat('MMM dd, yyyy').format(_dueDate)}'),
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14)),
                    ),
                    const SizedBox(height: 16),

                    // Attachments
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: PendingAttachmentSection(
                        attachments: _attachments,
                        onAdd: () async {
                          final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
                          if (result != null) {
                            setState(() => _attachments.addAll(result.files.map((f) => PendingAttachment(f))));
                          }
                        },
                        onRemove: (i) => setState(() => _attachments.removeAt(i)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Show collaborators toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.people_outline, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Show collaborators to assignee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                _showCollaborators
                                    ? 'Assignee can see all other people on this task.'
                                    : 'Assignee will not see other collaborators.',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _showCollaborators,
                          onChanged: (v) => setState(() => _showCollaborators = v),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                            onPressed: () => context.go('/tasks'),
                            child: const Text('Cancel')),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Text('Create Task'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
