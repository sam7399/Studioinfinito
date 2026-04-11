import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import '../features/notifications/widgets/notification_bell.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isWide = MediaQuery.of(context).size.width > 800;

    final sideNav = _SideNav(user: user);

    if (isWide) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Row(
          children: [
            SizedBox(width: 248, child: sideNav),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Image.asset('assets/images/gem_logo.png', height: 32),
        backgroundColor: GemColors.darkSurface,
        foregroundColor: Colors.white,
        actions: [
          NotificationBell(
            onPressed: () => context.push('/notifications'),
            iconColor: Colors.white,
          ),
        ],
      ),
      drawer: Drawer(child: sideNav),
      body: child,
    );
  }
}

class _SideNav extends ConsumerWidget {
  final dynamic user;
  const _SideNav({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final isSuperAdmin = user?.role == 'superadmin';
    final isManagement =
        user?.role == 'management' || isSuperAdmin;
    final isApprover = user?.role == 'manager' || 
        user?.role == 'department_head' || 
        isManagement;
    return Container(
      color: GemColors.darkSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Brand logo ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo image
                  Center(
                    child: Image.asset(
                      'assets/images/gem_logo.png',
                      height: 52,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Subtitle tag
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            GemColors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: GemColors.green
                                .withOpacity(0.35)),
                      ),
                      child: const Text(
                        'TSI Task Manager',
                        style: TextStyle(
                          color: GemColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── User chip ──────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: GemColors.green,
                  child: Text(
                    (user?.fullName ?? 'U').isNotEmpty
                        ? user!.fullName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'User',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        (user?.role ?? '').toUpperCase(),
                        style: TextStyle(
                            color: GemColors.green
                                .withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ]),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                  color: Colors.white.withOpacity(0.08),
                  height: 1),
            ),
            const SizedBox(height: 8),

            // ── Nav items ──────────────────────────────────────────────────
            _NavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                path: '/dashboard',
                currentLoc: loc),
            if (isManagement)
              _NavItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'Reports',
                  path: '/reports',
                  currentLoc: loc),
            _NavItem(
                icon: Icons.task_alt_outlined,
                label: 'Tasks',
                path: '/tasks',
                currentLoc: loc),
            if (isApprover)
              _NavItem(
                  icon: Icons.approval_outlined,
                  label: 'Approvals',
                  path: '/approvals',
                  currentLoc: loc),
            if (isManagement)
              _NavItem(
                  icon: Icons.group_outlined,
                  label: 'Users',
                  path: '/users',
                  currentLoc: loc),
            if (isManagement)
              _NavItem(
                  icon: Icons.import_export_outlined,
                  label: 'Import / Export',
                  path: '/import-export',
                  currentLoc: loc),
            if (isManagement)
              _NavItem(
                  icon: Icons.assessment_outlined,
                  label: 'HR Performance',
                  path: '/hr-performance',
                  currentLoc: loc),
            if (isSuperAdmin)
              _NavItem(
                  icon: Icons.corporate_fare_outlined,
                  label: 'Organization',
                  path: '/org',
                  currentLoc: loc),
            if (isSuperAdmin)
              _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'System Config',
                  path: '/system-config',
                  currentLoc: loc),

            const SizedBox(height: 8),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                  color: Colors.white.withOpacity(0.08),
                  height: 1),
            ),
            const SizedBox(height: 8),

            _NavItem(
                icon: Icons.lock_reset_outlined,
                label: 'Change Password',
                path: '/change-password',
                currentLoc: loc),
            _NavItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                path: '/notifications',
                currentLoc: loc),

            const Spacer(),

            // ── Bottom: version + logout ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
              child: Text(
                user?.companyName ?? 'The Studio Infinito',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.3),
                    letterSpacing: 0.4),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(
                'Designed by Personifycrafters',
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.18),
                    letterSpacing: 0.3),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout,
                    color: Colors.redAccent, size: 16),
                label: const Text('Logout',
                    style: TextStyle(
                        color: Colors.redAccent, fontSize: 13)),
                style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentLoc;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.currentLoc,
  });

  bool get _isActive {
    if (path == '/dashboard') return currentLoc == '/dashboard';
    if (path == '/tasks') {
      return currentLoc == '/tasks' ||
          (currentLoc.startsWith('/tasks/') &&
              RegExp(r'^/tasks/\d+').hasMatch(currentLoc));
    }
    if (path == '/notifications') {
      return currentLoc == '/notifications' ||
          currentLoc.startsWith('/notifications/');
    }
    return currentLoc.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: _isActive
            ? GemColors.green.withOpacity(0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            if (Scaffold.of(context).isDrawerOpen) {
              Navigator.of(context).pop();
            }
            context.go(path);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: _isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                          color: GemColors.green, width: 3),
                    ),
                  )
                : null,
            child: Row(children: [
              Icon(icon,
                  color: _isActive
                      ? GemColors.green
                      : Colors.white54,
                  size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color:
                      _isActive ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: _isActive
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}