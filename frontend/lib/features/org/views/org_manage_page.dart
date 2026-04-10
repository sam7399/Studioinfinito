import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/org_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../core/networking/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class OrgManagePage extends ConsumerStatefulWidget {
  const OrgManagePage({super.key});

  @override
  ConsumerState<OrgManagePage> createState() => _OrgManagePageState();
}

class _OrgManagePageState extends ConsumerState<OrgManagePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Organization',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage companies, departments, and locations',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabs,
                  labelColor: const Color(0xFF3B82F6),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF3B82F6),
                  tabs: const [
                    Tab(text: 'Companies'),
                    Tab(text: 'Departments'),
                    Tab(text: 'Locations'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _CompaniesTab(),
                _DepartmentsTab(),
                _LocationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Companies ─────────────────────────────────────────────────────────────────

class _CompaniesTab extends ConsumerWidget {
  const _CompaniesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(companiesProvider);
    final isSuperAdmin = ref.watch(authProvider).user?.role == 'superadmin';

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading companies: $e')),
      data: (companies) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${companies.length} ${companies.length == 1 ? 'company' : 'companies'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Spacer(),
                if (isSuperAdmin)
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Company'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => _CreateCompanyDialog(
                        onCreated: () => ref.invalidate(companiesProvider),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: companies.isEmpty
                ? Center(
                    child: Text('No companies yet',
                        style: TextStyle(color: Colors.grey.shade500)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: companies.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = companies[i];
                      return _OrgCard(
                        title: c.name,
                        subtitle: 'ID: ${c.id}',
                        icon: Icons.business_outlined,
                        onDelete: isSuperAdmin
                            ? () => _confirmDeactivate(
                                context, ref, c.id, c.name,
                                endpoint: ApiConstants.companyById(c.id),
                                invalidate: () =>
                                    ref.invalidate(companiesProvider))
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Departments ───────────────────────────────────────────────────────────────

class _DepartmentsTab extends ConsumerStatefulWidget {
  const _DepartmentsTab();

  @override
  ConsumerState<_DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends ConsumerState<_DepartmentsTab> {
  int? _companyId;

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider).maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final asyncDepts = ref.watch(departmentsProvider(_companyId));
    final role = ref.watch(authProvider).user?.role;
    final canManage = role == 'superadmin' || role == 'management';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _companyId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Company',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Companies')),
                    ...companies.map(
                        (c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _companyId = v),
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _CreateOrgItemDialog(
                      title: 'Create Department',
                      companies: companies,
                      defaultCompanyId: _companyId,
                      endpoint: ApiConstants.departments,
                      onCreated: () => ref.invalidate(departmentsProvider),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: asyncDepts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (depts) => depts.isEmpty
                ? Center(
                    child: Text('No departments found',
                        style: TextStyle(color: Colors.grey.shade500)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: depts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = depts[i];
                      return _OrgCard(
                        title: d.name,
                        subtitle: d.companyName != null
                            ? 'Company: ${d.companyName}'
                            : 'Company ID: ${d.companyId}',
                        icon: Icons.account_tree_outlined,
                        onDelete: canManage
                            ? () => _confirmDeactivate(
                                context, ref, d.id, d.name,
                                endpoint: ApiConstants.departmentById(d.id),
                                invalidate: () =>
                                    ref.invalidate(departmentsProvider))
                            : null,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Locations ─────────────────────────────────────────────────────────────────

class _LocationsTab extends ConsumerStatefulWidget {
  const _LocationsTab();

  @override
  ConsumerState<_LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends ConsumerState<_LocationsTab> {
  int? _companyId;

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider).maybeWhen(data: (d) => d, orElse: () => <OrgItem>[]);
    final asyncLocs = ref.watch(locationsProvider(_companyId));
    final role = ref.watch(authProvider).user?.role;
    final canManage = role == 'superadmin' || role == 'management';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _companyId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Company',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Companies')),
                    ...companies.map(
                        (c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _companyId = v),
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _CreateOrgItemDialog(
                      title: 'Create Location',
                      companies: companies,
                      defaultCompanyId: _companyId,
                      endpoint: ApiConstants.locations,
                      onCreated: () => ref.invalidate(locationsProvider),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: asyncLocs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (locs) => locs.isEmpty
                ? Center(
                    child: Text('No locations found',
                        style: TextStyle(color: Colors.grey.shade500)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: locs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final l = locs[i];
                      return _OrgCard(
                        title: l.name,
                        subtitle: l.companyName != null
                            ? 'Company: ${l.companyName}'
                            : 'Company ID: ${l.companyId}',
                        icon: Icons.location_on_outlined,
                        onDelete: canManage
                            ? () => _confirmDeactivate(
                                context, ref, l.id, l.name,
                                endpoint: ApiConstants.locationById(l.id),
                                invalidate: () =>
                                    ref.invalidate(locationsProvider))
                            : null,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

Future<void> _confirmDeactivate(
  BuildContext context,
  WidgetRef ref,
  int id,
  String name, {
  required String endpoint,
  required VoidCallback invalidate,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm Deactivation'),
      content: Text('Deactivate "$name"? It can be re-enabled later.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Deactivate'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(dioProvider).delete(endpoint);
    invalidate();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"$name" deactivated')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

// ── _OrgCard ──────────────────────────────────────────────────────────────────

class _OrgCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onDelete;

  const _OrgCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Deactivate',
            ),
        ],
      ),
    );
  }
}

// ── Create Company dialog ──────────────────────────────────────────────────────

class _CreateCompanyDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateCompanyDialog({required this.onCreated});

  @override
  ConsumerState<_CreateCompanyDialog> createState() =>
      _CreateCompanyDialogState();
}

class _CreateCompanyDialogState extends ConsumerState<_CreateCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(ApiConstants.companies, data: {
        'name': _nameCtrl.text.trim(),
        if (_domainCtrl.text.trim().isNotEmpty) 'domain': _domainCtrl.text.trim(),
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Company'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Company Name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _domainCtrl,
              decoration: const InputDecoration(
                  labelText: 'Domain (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. company.com'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ── Generic create dialog (Department / Location) ─────────────────────────────

class _CreateOrgItemDialog extends ConsumerStatefulWidget {
  final String title;
  final List<OrgItem> companies;
  final int? defaultCompanyId;
  final String endpoint;
  final VoidCallback onCreated;

  const _CreateOrgItemDialog({
    required this.title,
    required this.companies,
    this.defaultCompanyId,
    required this.endpoint,
    required this.onCreated,
  });

  @override
  ConsumerState<_CreateOrgItemDialog> createState() =>
      _CreateOrgItemDialogState();
}

class _CreateOrgItemDialogState extends ConsumerState<_CreateOrgItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  int? _companyId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _companyId = widget.defaultCompanyId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(widget.endpoint, data: {
        'name': _nameCtrl.text.trim(),
        'company_id': _companyId,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _companyId,
              decoration: const InputDecoration(
                  labelText: 'Company *', border: OutlineInputBorder()),
              items: widget.companies
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _companyId = v),
              validator: (v) => v == null ? 'Select a company' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
