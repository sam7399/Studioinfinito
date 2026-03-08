import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../../org/providers/org_provider.dart';
import '../../config/providers/system_config_provider.dart';
import '../../../core/theme/app_theme.dart';

class UserFormPage extends ConsumerStatefulWidget {
  const UserFormPage({super.key});

  @override
  ConsumerState<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends ConsumerState<UserFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Personal info
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _empCodeCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  DateTime? _dob;
  bool _obscurePass = true;

  // Org fields
  String _role = 'employee';
  int? _companyId;
  int? _departmentId;
  int? _locationId;
  int? _managerId;
  int? _departmentHeadId;
  List<int> _companyIds = [];
  List<int> _locationIds = [];

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _empCodeCtrl.dispose();
    _usernameCtrl.dispose();
    _designationCtrl.dispose();
    _passwordCtrl.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final config = ref.read(systemConfigProvider);

    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'role': _role,
      'department_id': _departmentId,
    };

    // Company: send both single and multi depending on mode
    if (config.multiCompany) {
      body['company_ids'] = _companyIds;
      body['company_id'] = _companyIds.isNotEmpty ? _companyIds.first : null;
    } else {
      body['company_id'] = _companyId;
    }

    // Location: send both single and multi depending on mode
    if (config.multiLocation) {
      body['location_ids'] = _locationIds;
      body['location_id'] = _locationIds.isNotEmpty ? _locationIds.first : null;
    } else {
      body['location_id'] = _locationId;
    }

    if (_phoneCtrl.text.isNotEmpty) body['phone'] = _phoneCtrl.text.trim();
    if (_empCodeCtrl.text.isNotEmpty) body['emp_code'] = _empCodeCtrl.text.trim();
    if (_usernameCtrl.text.isNotEmpty) body['username'] = _usernameCtrl.text.trim();
    if (_designationCtrl.text.isNotEmpty) body['designation'] = _designationCtrl.text.trim();
    if (_dob != null) body['date_of_birth'] = DateFormat('yyyy-MM-dd').format(_dob!);
    if (_managerId != null) body['manager_id'] = _managerId;
    if (_departmentHeadId != null) body['department_head_id'] = _departmentHeadId;

    final ok = await ref.read(userProvider.notifier).createUser(body);

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User created successfully')));
        context.go('/users');
      } else {
        setState(() {
          _error = ref.read(userProvider).error ?? 'Failed to create user';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider)
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final depts = ref.watch(departmentsProvider(_companyId))
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final locs = ref.watch(locationsProvider(_companyId))
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final managers = ref.watch(managersDropdownProvider)
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final deptHeads = ref.watch(deptHeadsDropdownProvider)
        .maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                    onPressed: () => context.go('/users'),
                    icon: const Icon(Icons.arrow_back)),
                const SizedBox(width: 8),
                Text('Create User',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Personal Information ───────────────────────────
                  _SectionCard(
                    title: 'Personal Information',
                    icon: Icons.person_outline,
                    child: Column(
                      children: [
                        _Row2([
                          _Field(
                            ctrl: _nameCtrl,
                            label: 'Full Name *',
                            icon: Icons.badge_outlined,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          _Field(
                            ctrl: _emailCtrl,
                            label: 'Email *',
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || !v.contains('@'))
                                    ? 'Valid email required'
                                    : null,
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _Row2([
                          _Field(
                            ctrl: _empCodeCtrl,
                            label: 'Emp Code',
                            icon: Icons.numbers_outlined,
                          ),
                          _Field(
                            ctrl: _usernameCtrl,
                            label: 'Username',
                            icon: Icons.alternate_email_outlined,
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _Row2([
                          _Field(
                            ctrl: _phoneCtrl,
                            label: 'Mobile No',
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone,
                          ),
                          // Date of Birth picker
                          InkWell(
                            onTap: _pickDob,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date of Birth',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(
                                    Icons.cake_outlined,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Professional Information ───────────────────────
                  _SectionCard(
                    title: 'Professional Information',
                    icon: Icons.work_outline,
                    child: Column(
                      children: [
                        _Row2([
                          _Field(
                            ctrl: _designationCtrl,
                            label: 'Designation',
                            icon: Icons.card_membership_outlined,
                          ),
                          DropdownButtonFormField<String>(
                            value: _role,
                            decoration: const InputDecoration(
                              labelText: 'Role *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.manage_accounts_outlined,
                                  size: 18),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'employee',
                                  child: Text('Employee')),
                              DropdownMenuItem(
                                  value: 'manager',
                                  child: Text('Manager')),
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
                        const SizedBox(height: 16),

                        // Company filter (single or multi based on config)
                        Consumer(builder: (context, ref, _) {
                          final config = ref.watch(systemConfigProvider);
                          if (!config.multiCompany) {
                            return DropdownButtonFormField<int?>(
                              value: _companyId,
                              decoration: const InputDecoration(
                                labelText: 'Select Company',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business_outlined, size: 18),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('-- Select Company --')),
                                ...companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                              ],
                              onChanged: (v) => setState(() {
                                _companyId = v;
                                _companyIds = v != null ? [v] : [];
                                _departmentId = null;
                                _locationId = null;
                                _locationIds = [];
                              }),
                            );
                          }
                          return _MultiSelectField(
                            label: 'Companies',
                            icon: Icons.business_outlined,
                            allItems: companies,
                            selectedIds: _companyIds,
                            onChanged: (ids) => setState(() {
                              _companyIds = ids;
                              _companyId = ids.isNotEmpty ? ids.first : null;
                              _departmentId = null;
                              _locationId = null;
                              _locationIds = [];
                            }),
                          );
                        }),
                        const SizedBox(height: 16),

                        _Row2([
                          DropdownButtonFormField<int>(
                            value: _departmentId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Department *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.workspaces_outlined,
                                  size: 18),
                            ),
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
                          // Location (single or multi based on config)
                          Consumer(builder: (context, ref, _) {
                            final config = ref.watch(systemConfigProvider);
                            if (!config.multiLocation) {
                              return DropdownButtonFormField<int>(
                                value: _locationId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Location *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                                ),
                                items: locs
                                    .map((l) => DropdownMenuItem(
                                        value: l.id,
                                        child: Text(l.name,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _locationId = v;
                                  _locationIds = v != null ? [v] : [];
                                }),
                                validator: (v) => v == null ? 'Required' : null,
                              );
                            }
                            return _MultiSelectField(
                              label: 'Locations',
                              icon: Icons.location_on_outlined,
                              allItems: locs,
                              selectedIds: _locationIds,
                              onChanged: (ids) => setState(() {
                                _locationIds = ids;
                                _locationId = ids.isNotEmpty ? ids.first : null;
                              }),
                            );
                          }),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Reporting Structure ────────────────────────────
                  _SectionCard(
                    title: 'Reporting Structure',
                    icon: Icons.account_tree_outlined,
                    child: _Row2([
                      DropdownButtonFormField<int?>(
                        value: _managerId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Manager',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.supervisor_account_outlined, size: 18),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('-- None --')),
                          ...managers.map((u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() => _managerId = v),
                      ),
                      DropdownButtonFormField<int?>(
                        value: _departmentHeadId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Department Head',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.corporate_fare_outlined,
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
                  ),
                  const SizedBox(height: 16),

                  // ── Account ────────────────────────────────────────
                  _SectionCard(
                    title: 'Account',
                    icon: Icons.lock_outline,
                    child: TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outlined, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                        helperText: 'Minimum 8 characters',
                      ),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Min 8 characters'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13)),
                    ),
                  if (_error != null) const SizedBox(height: 16),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                          onPressed: () => context.go('/users'),
                          child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.person_add_outlined, size: 18),
                        label:
                            Text(_loading ? 'Creating...' : 'Create User'),
                        onPressed: _loading ? null : _submit,
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

// ── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
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
              Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── 2-column responsive row ───────────────────────────────────────────────────

class _Row2 extends StatelessWidget {
  final List<Widget> children;
  const _Row2(this.children);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      if (c.maxWidth > 500) {
        return Row(
          children: children
              .expand((w) sync* {
                yield Expanded(child: w);
                if (w != children.last) yield const SizedBox(width: 16);
              })
              .toList(),
        );
      }
      return Column(
        children: children
            .expand((w) sync* {
              yield w;
              if (w != children.last) yield const SizedBox(height: 12);
            })
            .toList(),
      );
    });
  }
}

// ── Text field helper ─────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData? icon;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;

  const _Field(
      {required this.ctrl,
      required this.label,
      this.icon,
      this.keyboard,
      this.validator});

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
      validator: validator,
    );
  }
}

// ── Multi-select field ────────────────────────────────────────────────────────

class _MultiSelectField extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<OrgItem> allItems;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;
  const _MultiSelectField({
    required this.label,
    required this.icon,
    required this.allItems,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = allItems.where((i) => selectedIds.contains(i.id)).toList();
    return InkWell(
      onTap: () async {
        final result = await showDialog<List<int>>(
          context: context,
          builder: (_) => _MultiSelectDialog(
            label: label,
            allItems: allItems,
            initialSelected: List.from(selectedIds),
          ),
        );
        if (result != null) onChanged(result);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, size: 18),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: selected.isEmpty
            ? Text('Select $label',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14))
            : Wrap(
                spacing: 6,
                children: selected
                    .map((item) => Chip(
                          label: Text(item.name,
                              style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            final newIds = List<int>.from(selectedIds)
                              ..remove(item.id);
                            onChanged(newIds);
                          },
                          backgroundColor:
                              GemColors.green.withOpacity(0.12),
                          side: BorderSide(
                              color: GemColors.green.withOpacity(0.3)),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final String label;
  final List<OrgItem> allItems;
  final List<int> initialSelected;
  const _MultiSelectDialog({
    required this.label,
    required this.allItems,
    required this.initialSelected,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late List<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select ${widget.label}'),
      content: SizedBox(
        width: 300,
        child: ListView(
          shrinkWrap: true,
          children: widget.allItems
              .map((item) => CheckboxListTile(
                    title: Text(item.name),
                    value: _selected.contains(item.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(item.id);
                      } else {
                        _selected.remove(item.id);
                      }
                    }),
                    activeColor: GemColors.green,
                    dense: true,
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Done')),
      ],
    );
  }
}
