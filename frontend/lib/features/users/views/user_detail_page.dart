import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/dio_client.dart';
import '../../org/providers/org_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _userDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final res = await ref.watch(dioProvider).get(ApiConstants.userById(id));
  return res.data['data'] as Map<String, dynamic>;
});

final _workloadProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final res = await ref.watch(dioProvider).get(ApiConstants.userWorkload(id));
  return res.data['data'] as Map<String, dynamic>;
});

final _performanceProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final res =
      await ref.watch(dioProvider).get(ApiConstants.userPerformance(id));
  return res.data['data'] as Map<String, dynamic>;
});

// ── Page ──────────────────────────────────────────────────────────────────────

class UserDetailPage extends ConsumerWidget {
  final int userId;
  const UserDetailPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(_userDetailProvider(userId));
    final workloadAsync = ref.watch(_workloadProvider(userId));
    final perfAsync = ref.watch(_performanceProvider(userId));
    final currentUser = ref.watch(authProvider).user;
    final canEdit = currentUser?.role == 'superadmin' ||
        currentUser?.role == 'management';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                    onPressed: () => context.go('/users'),
                    icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 8),
                Text('User Profile',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),

            // ── User info card ────────────────────────────────────────
            userAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _errorBox('Could not load user: $e'),
              data: (u) =>
                  _UserInfoCard(user: u, canEdit: canEdit, userId: userId),
            ),
            const SizedBox(height: 24),

            // ── Workload + Performance ─────────────────────────────────
            LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth > 680;
              final wCard = workloadAsync.when(
                loading: () => _shimmerCard('Current Workload'),
                error: (e, _) =>
                    _errorCard('Workload', 'Could not load workload'),
                data: (d) => _WorkloadCard(data: d),
              );
              final pCard = perfAsync.when(
                loading: () => _shimmerCard('Performance'),
                error: (e, _) =>
                    _errorCard('Performance', 'Could not load performance'),
                data: (d) => _PerformanceCard(data: d),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: wCard),
                    const SizedBox(width: 16),
                    Expanded(child: pCard),
                  ],
                );
              }
              return Column(children: [
                wCard,
                const SizedBox(height: 16),
                pCard
              ]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12)),
        child: Text(msg, style: TextStyle(color: Colors.red.shade700)),
      );

  Widget _shimmerCard(String title) => _CardShell(
        title: title,
        child: const SizedBox(
            height: 80, child: Center(child: CircularProgressIndicator())),
      );

  Widget _errorCard(String title, String msg) => _CardShell(
        title: title,
        child: Text(msg, style: const TextStyle(color: Colors.grey)),
      );
}

// ── User info card ─────────────────────────────────────────────────────────────

class _UserInfoCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final bool canEdit;
  final int userId;
  const _UserInfoCard(
      {required this.user, required this.canEdit, required this.userId});

  @override
  ConsumerState<_UserInfoCard> createState() => _UserInfoCardState();
}

class _UserInfoCardState extends ConsumerState<_UserInfoCard> {
  bool _toggling = false;

  Color _roleColor(String role) => switch (role) {
        'superadmin' => const Color(0xFFEF4444),
        'management' => const Color(0xFF3B82F6),
        'department_head' => const Color(0xFF8B5CF6),
        'manager' => const Color(0xFF0D9488),
        _ => Colors.grey,
      };

  String _roleLabel(String role) => switch (role) {
        'superadmin' => 'Super Admin',
        'management' => 'Management',
        'department_head' => 'Dept Head',
        'manager' => 'Manager',
        _ => 'Employee',
      };

  Future<void> _toggleActive() async {
    final isActive = widget.user['is_active'] as bool? ?? true;
    setState(() => _toggling = true);
    try {
      await ref
          .read(dioProvider)
          .put(ApiConstants.userById(widget.userId),
              data: {'is_active': !isActive});
      ref.invalidate(_userDetailProvider(widget.userId));
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                e.response?.data?['message'] ?? 'Update failed'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _showEditDialog() async {
    final companies = ref.read(companiesProvider).maybeWhen(
        data: (d) => d, orElse: () => <OrgItem>[]);
    await showDialog(
      context: context,
      builder: (_) => _EditDialog(
        userId: widget.userId,
        user: widget.user,
        companies: companies,
        onSaved: () => ref.invalidate(_userDetailProvider(widget.userId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final name = u['name'] as String? ?? 'Unknown';
    final email = u['email'] as String? ?? '';
    final role = u['role'] as String? ?? 'employee';
    final isActive = u['is_active'] as bool? ?? true;
    final phone = u['phone'] as String?;
    final company = (u['company'] as Map<String, dynamic>?)?['name'] as String?;
    final dept =
        (u['department'] as Map<String, dynamic>?)?['name'] as String?;
    final loc = (u['location'] as Map<String, dynamic>?)?['name'] as String?;
    final roleColor = _roleColor(role);

    return Container(
      padding: const EdgeInsets.all(24),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 32,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: roleColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                        // Active badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(email,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 8),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _roleLabel(role),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: roleColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Info grid
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if (company != null) _InfoChip(Icons.business_outlined, company),
              if (dept != null) _InfoChip(Icons.workspaces_outlined, dept),
              if (loc != null)
                _InfoChip(Icons.location_on_outlined, loc),
              if (phone != null && phone.isNotEmpty)
                _InfoChip(Icons.phone_outlined, phone),
            ],
          ),
          if (widget.canEdit) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  onPressed: _showEditDialog,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: _toggling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          isActive
                              ? Icons.person_off_outlined
                              : Icons.person_outlined,
                          size: 16),
                  label: Text(isActive ? 'Deactivate' : 'Activate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isActive ? Colors.red : Colors.green,
                    side: BorderSide(
                        color: isActive ? Colors.red : Colors.green),
                  ),
                  onPressed: _toggling ? null : _toggleActive,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
      ],
    );
  }
}

// ── Edit dialog ───────────────────────────────────────────────────────────────

class _EditDialog extends ConsumerStatefulWidget {
  final int userId;
  final Map<String, dynamic> user;
  final List<OrgItem> companies;
  final VoidCallback onSaved;
  const _EditDialog(
      {required this.userId,
      required this.user,
      required this.companies,
      required this.onSaved});

  @override
  ConsumerState<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends ConsumerState<_EditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _empCodeCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _designationCtrl;
  late final TextEditingController _newPasswordCtrl;
  late String _role;
  int? _companyId;
  int? _departmentId;
  int? _locationId;
  int? _managerId;
  int? _departmentHeadId;
  DateTime? _dob;
  bool _obscurePass = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u['name'] as String? ?? '');
    _emailCtrl = TextEditingController(text: u['email'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: u['phone'] as String? ?? '');
    _empCodeCtrl = TextEditingController(text: u['emp_code'] as String? ?? '');
    _usernameCtrl = TextEditingController(text: u['username'] as String? ?? '');
    _designationCtrl =
        TextEditingController(text: u['designation'] as String? ?? '');
    _newPasswordCtrl = TextEditingController();
    _role = u['role'] as String? ?? 'employee';
    _companyId =
        (u['company'] as Map<String, dynamic>?)?['id'] as int?;
    _departmentId =
        (u['department'] as Map<String, dynamic>?)?['id'] as int?;
    _locationId =
        (u['location'] as Map<String, dynamic>?)?['id'] as int?;
    _managerId =
        (u['manager'] as Map<String, dynamic>?)?['id'] as int?;
    _departmentHeadId =
        (u['department_head'] as Map<String, dynamic>?)?['id'] as int?;
    final dobStr = u['date_of_birth'] as String?;
    if (dobStr != null && dobStr.isNotEmpty) {
      _dob = DateTime.tryParse(dobStr);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _empCodeCtrl.dispose();
    _usernameCtrl.dispose();
    _designationCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'role': _role,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'department_id': _departmentId,
        'location_id': _locationId,
        'manager_id': _managerId,
        'department_head_id': _departmentHeadId,
      };
      if (_phoneCtrl.text.trim().isNotEmpty) {
        body['phone'] = _phoneCtrl.text.trim();
      }
      if (_empCodeCtrl.text.trim().isNotEmpty) {
        body['emp_code'] = _empCodeCtrl.text.trim();
      }
      if (_usernameCtrl.text.trim().isNotEmpty) {
        body['username'] = _usernameCtrl.text.trim();
      }
      if (_designationCtrl.text.trim().isNotEmpty) {
        body['designation'] = _designationCtrl.text.trim();
      }
      if (_dob != null) {
        body['date_of_birth'] = DateFormat('yyyy-MM-dd').format(_dob!);
      }
      if (_newPasswordCtrl.text.isNotEmpty) {
        body['password'] = _newPasswordCtrl.text;
      }
      await ref
          .read(dioProvider)
          .put(ApiConstants.userById(widget.userId), data: body);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['message'] ?? 'Update failed';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentsProvider(_companyId)).maybeWhen(
        data: (d) => d, orElse: () => <OrgItem>[]);
    final locs = ref.watch(locationsProvider(_companyId)).maybeWhen(
        data: (d) => d, orElse: () => <OrgItem>[]);
    final managers = ref.watch(managersDropdownProvider).maybeWhen(
        data: (d) => d, orElse: () => <OrgItem>[]);
    final deptHeads = ref.watch(deptHeadsDropdownProvider).maybeWhen(
        data: (d) => d, orElse: () => <OrgItem>[]);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined,
                      size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Edit User',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Personal Information ───────────────────────────
                    _SectionHeader('Personal Information',
                        Icons.person_outline),
                    const SizedBox(height: 12),
                    _Row2([
                      _EditField(
                          ctrl: _nameCtrl,
                          label: 'Full Name',
                          icon: Icons.badge_outlined),
                      _EditField(
                          ctrl: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboard: TextInputType.emailAddress),
                    ]),
                    const SizedBox(height: 12),
                    _Row2([
                      _EditField(
                          ctrl: _empCodeCtrl,
                          label: 'Emp Code',
                          icon: Icons.numbers_outlined),
                      _EditField(
                          ctrl: _usernameCtrl,
                          label: 'Username',
                          icon: Icons.alternate_email_outlined),
                    ]),
                    const SizedBox(height: 12),
                    _Row2([
                      _EditField(
                          ctrl: _phoneCtrl,
                          label: 'Mobile No',
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone),
                      // DOB picker
                      InkWell(
                        onTap: _pickDob,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of Birth',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.cake_outlined,
                                size: 18),
                            suffixIcon: _dob != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () =>
                                        setState(() => _dob = null))
                                : const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16),
                          ),
                          child: Text(
                            _dob != null
                                ? DateFormat('dd MMM yyyy').format(_dob!)
                                : 'Select date',
                            style: TextStyle(
                                color: _dob != null
                                    ? null
                                    : Colors.grey.shade500,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Professional Information ───────────────────────
                    _SectionHeader(
                        'Professional Information', Icons.work_outline),
                    const SizedBox(height: 12),
                    _Row2([
                      _EditField(
                          ctrl: _designationCtrl,
                          label: 'Designation',
                          icon: Icons.card_membership_outlined),
                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                              Icons.manage_accounts_outlined,
                              size: 18),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'employee', child: Text('Employee')),
                          DropdownMenuItem(
                              value: 'manager', child: Text('Manager')),
                          DropdownMenuItem(
                              value: 'department_head',
                              child: Text('Department Head')),
                          DropdownMenuItem(
                              value: 'management',
                              child: Text('Management')),
                          DropdownMenuItem(
                              value: 'superadmin',
                              child: Text('Super Admin')),
                        ],
                        onChanged: (v) => setState(() => _role = v!),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (widget.companies.isNotEmpty) ...[
                      DropdownButtonFormField<int?>(
                        value: widget.companies.any((c) => c.id == _companyId)
                            ? _companyId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Company',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.business_outlined, size: 18),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('-- Select Company --')),
                          ...widget.companies.map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (v) => setState(() {
                          _companyId = v;
                          _departmentId = null;
                          _locationId = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _Row2([
                      DropdownButtonFormField<int?>(
                        value: depts.any((d) => d.id == _departmentId)
                            ? _departmentId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.workspaces_outlined, size: 18),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('-- None --')),
                          ...depts.map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) =>
                            setState(() => _departmentId = v),
                      ),
                      DropdownButtonFormField<int?>(
                        value: locs.any((l) => l.id == _locationId)
                            ? _locationId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.location_on_outlined, size: 18),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('-- None --')),
                          ...locs.map((l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) =>
                            setState(() => _locationId = v),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Reporting Structure ────────────────────────────
                    _SectionHeader(
                        'Reporting Structure', Icons.account_tree_outlined),
                    const SizedBox(height: 12),
                    _Row2([
                      DropdownButtonFormField<int?>(
                        value: managers.any((u) => u.id == _managerId)
                            ? _managerId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Manager',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                              Icons.supervisor_account_outlined,
                              size: 18),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('-- None --')),
                          ...managers.map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) =>
                            setState(() => _managerId = v),
                      ),
                      DropdownButtonFormField<int?>(
                        value: deptHeads.any((u) => u.id == _departmentHeadId)
                            ? _departmentHeadId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Department Head',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                              Icons.corporate_fare_outlined,
                              size: 18),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('-- None --')),
                          ...deptHeads.map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) =>
                            setState(() => _departmentHeadId = v),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Reset Password ─────────────────────────────────
                    _SectionHeader('Reset Password', Icons.lock_outline),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: 'New Password (leave blank to keep current)',
                        border: const OutlineInputBorder(),
                        prefixIcon:
                            const Icon(Icons.lock_outlined, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer actions
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes'),
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

// ── Edit dialog helpers ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF374151))),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _Row2 extends StatelessWidget {
  final List<Widget> children;
  const _Row2(this.children);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand((w) sync* {
            yield Expanded(child: w);
            if (w != children.last) yield const SizedBox(width: 12);
          })
          .toList(),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData? icon;
  final TextInputType? keyboard;

  const _EditField(
      {required this.ctrl,
      required this.label,
      this.icon,
      this.keyboard});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      ),
    );
  }
}

// ── Workload card ─────────────────────────────────────────────────────────────

class _WorkloadCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _WorkloadCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final counts = (data['task_counts'] as Map<String, dynamic>?) ?? {};
    final overdue = (data['overdue_tasks'] as num?)?.toInt() ?? 0;
    final upcoming = (data['upcoming_tasks'] as num?)?.toInt() ?? 0;
    final hours =
        (data['total_estimated_hours'] as num?)?.toDouble() ?? 0.0;

    final statusItems = [
      _WItem('Open', counts['open'] ?? 0, const Color(0xFFF59E0B)),
      _WItem('In Progress', counts['in_progress'] ?? 0, const Color(0xFF8B5CF6)),
      _WItem('Pending Review', counts['pending_review'] ?? 0, const Color(0xFFF97316)),
    ];

    return _CardShell(
      title: 'Current Workload',
      icon: Icons.work_outline,
      child: Column(
        children: [
          // Status counts
          Row(
            children: statusItems
                .map((item) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text('${item.value}',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: item.color)),
                            const SizedBox(height: 2),
                            Text(item.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          // Overdue + Upcoming + Hours
          Row(
            children: [
              Expanded(
                  child: _MetricTile(
                      icon: Icons.warning_outlined,
                      label: 'Overdue',
                      value: '$overdue',
                      color: overdue > 0
                          ? const Color(0xFFEF4444)
                          : Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricTile(
                      icon: Icons.upcoming_outlined,
                      label: 'Due This Week',
                      value: '$upcoming',
                      color: const Color(0xFF3B82F6))),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricTile(
                      icon: Icons.schedule_outlined,
                      label: 'Est. Hours',
                      value: '${hours.toStringAsFixed(1)}h',
                      color: const Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }
}

class _WItem {
  final String label;
  final dynamic value;
  final Color color;
  const _WItem(this.label, this.value, this.color);
}

// ── Performance card ───────────────────────────────────────────────────────────

class _PerformanceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PerformanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final completed = (data['completed_tasks'] as num?)?.toInt() ?? 0;
    final reviewCount = (data['review_count'] as num?)?.toInt() ?? 0;
    final onTimeRate =
        (data['on_time_completion_rate'] as num?)?.toDouble() ?? 0.0;
    final avgDays =
        (data['avg_completion_days'] as num?)?.toDouble() ?? 0.0;
    final avgRating = data['avg_rating'] != null
        ? double.tryParse('${data['avg_rating']}')
        : null;
    final avgQuality = data['avg_quality_score'] != null
        ? double.tryParse('${data['avg_quality_score']}')
        : null;
    final avgTimeliness = data['avg_timeliness_score'] != null
        ? double.tryParse('${data['avg_timeliness_score']}')
        : null;

    return _CardShell(
      title: 'Performance Metrics',
      icon: Icons.insights_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _MetricTile(
                      icon: Icons.check_circle_outline,
                      label: 'Completed',
                      value: '$completed',
                      color: const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricTile(
                      icon: Icons.star_outline,
                      label: 'Reviews',
                      value: '$reviewCount',
                      color: const Color(0xFF8B5CF6))),
              const SizedBox(width: 8),
              Expanded(
                  child: _MetricTile(
                      icon: Icons.timelapse_outlined,
                      label: 'Avg Days',
                      value: avgDays > 0 ? '${avgDays.toStringAsFixed(1)}d' : '—',
                      color: const Color(0xFF3B82F6))),
            ],
          ),
          const SizedBox(height: 16),

          // On-time rate bar
          _RateBar(
            label: 'On-time Completion',
            value: onTimeRate / 100,
            displayText: '${onTimeRate.toStringAsFixed(1)}%',
            color: onTimeRate >= 80
                ? const Color(0xFF10B981)
                : onTimeRate >= 50
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444),
          ),
          const SizedBox(height: 10),

          // Score bars (only if reviews exist)
          if (reviewCount > 0) ...[
            if (avgRating != null)
              _RateBar(
                  label: 'Avg Rating',
                  value: avgRating / 5,
                  displayText: avgRating.toStringAsFixed(2),
                  color: const Color(0xFFF59E0B)),
            if (avgQuality != null) ...[
              const SizedBox(height: 8),
              _RateBar(
                  label: 'Avg Quality',
                  value: avgQuality / 5,
                  displayText: avgQuality.toStringAsFixed(2),
                  color: const Color(0xFF3B82F6)),
            ],
            if (avgTimeliness != null) ...[
              const SizedBox(height: 8),
              _RateBar(
                  label: 'Avg Timeliness',
                  value: avgTimeliness / 5,
                  displayText: avgTimeliness.toStringAsFixed(2),
                  color: const Color(0xFF8B5CF6)),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('No reviews yet',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _RateBar extends StatelessWidget {
  final String label;
  final double value; // 0.0 – 1.0
  final String displayText;
  final Color color;
  const _RateBar(
      {required this.label,
      required this.value,
      required this.displayText,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
            Text(displayText,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  const _CardShell({required this.title, this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
              ],
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
