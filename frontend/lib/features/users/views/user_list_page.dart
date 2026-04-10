import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../providers/user_provider.dart';

// All 5 roles with labels + colors
const _roleLabels = {
  'superadmin': 'Super Admin',
  'management': 'Management',
  'department_head': 'Dept Head',
  'manager': 'Manager',
  'employee': 'Employee',
};

Color _roleColor(String role) => switch (role) {
      'superadmin' => const Color(0xFFEF4444),
      'management' => const Color(0xFF3B82F6),
      'department_head' => const Color(0xFF8B5CF6),
      'manager' => const Color(0xFF0D9488),
      _ => Colors.grey,
    };

class UserListPage extends ConsumerStatefulWidget {
  const UserListPage({super.key});

  @override
  ConsumerState<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends ConsumerState<UserListPage> {
  final _searchCtrl = TextEditingController();
  String? _roleFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(userProvider.notifier).fetchUsers(
      filters: {
        if (_searchCtrl.text.isNotEmpty) 'search': _searchCtrl.text,
        if (_roleFilter != null) 'role': _roleFilter,
      },
      reset: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userProvider);
    final currentUser = ref.watch(authProvider).user;
    final isSuperAdmin = currentUser?.role == 'superadmin';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Users',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${state.total} total users',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/import-export'),
                  icon: const Icon(Icons.upload_outlined, size: 16),
                  label: const Text('Import / Export'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => context.go('/users/create'),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add User'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Filters ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String?>(
                      value: _roleFilter,
                      hint: const Text('All Roles',
                          style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All Roles')),
                        ..._roleLabels.entries.map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value,
                                style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) {
                        setState(() => _roleFilter = v);
                        _applyFilters();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(userProvider.notifier).fetchUsers(reset: true),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Table ────────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8)
                  ],
                ),
                child: Builder(builder: (_) {
                  if (state.isLoading && state.users.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.error != null && state.users.isEmpty) {
                    return Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(state.error!,
                                style:
                                    TextStyle(color: Colors.red.shade400)),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: () => ref
                                    .read(userProvider.notifier)
                                    .fetchUsers(reset: true),
                                child: const Text('Retry')),
                          ]),
                    );
                  }
                  if (state.users.isEmpty) {
                    return const Center(child: Text('No users found.'));
                  }

                  return Column(
                    children: [
                      // Header row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey.shade200)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: Text('NAME',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.grey))),
                            Expanded(
                                flex: 3,
                                child: Text('EMAIL',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.grey))),
                            Expanded(
                                flex: 2,
                                child: Text('ROLE',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.grey))),
                            Expanded(
                                flex: 1,
                                child: Text('STATUS',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.grey))),
                            SizedBox(width: 100),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: state.users.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade100),
                          itemBuilder: (_, i) => _UserRow(
                            user: state.users[i],
                            isSuperAdmin: isSuperAdmin,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  final UserModel user;
  final bool isSuperAdmin;
  const _UserRow({required this.user, required this.isSuperAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _roleColor(user.role);
    final label = _roleLabels[user.role] ?? user.role;

    return InkWell(
      onTap: () => context.go('/users/${user.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Name + avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(user.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13),
                          overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            // Email
            Expanded(
                flex: 3,
                child: Text(user.email,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis)),
            // Role badge
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            // Active toggle
            Expanded(
              flex: 1,
              child: Switch.adaptive(
                value: user.isActive,
                onChanged: (_) => ref
                    .read(userProvider.notifier)
                    .toggleActive(user.id, user.isActive),
              ),
            ),
            // Actions
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.visibility_outlined,
                        color: Colors.blue.shade400, size: 18),
                    tooltip: 'View Profile',
                    onPressed: () => context.go('/users/${user.id}'),
                  ),
                  if (isSuperAdmin)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.red.shade400, size: 18),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Delete ${user.fullName}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ref
                  .read(userProvider.notifier)
                  .deleteUser(user.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        ref.read(userProvider).error ?? 'Delete failed'),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
