import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth/providers/auth_provider.dart';
import 'auth/views/login_page.dart';
import 'auth/views/forgot_password_page.dart';
import 'auth/views/change_password_page.dart';
import 'features/dashboard/views/dashboard_page.dart';
import 'features/tasks/views/task_list_page.dart';
import 'features/tasks/views/task_create_page.dart';
import 'features/tasks/views/task_detail_page.dart';
import 'features/tasks/views/task_bulk_assign_page.dart';
import 'features/tasks/views/task_create_multi_page.dart';
import 'features/users/views/user_list_page.dart';
import 'features/users/views/user_form_page.dart';
import 'features/users/views/user_detail_page.dart';
import 'features/org/views/org_manage_page.dart';
import 'features/reports/views/reports_page.dart';
import 'features/import_export/views/import_export_page.dart';
import 'features/config/views/system_config_page.dart';
import 'features/hr/views/hr_performance_page.dart';
import 'widgets/app_shell.dart';

/// Bridges Riverpod auth state into a ChangeNotifier so GoRouter's
/// refreshListenable can re-evaluate redirects without recreating the router.
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;

  AuthState get authState => _ref.read(authProvider);
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = notifier.authState;
      final isLoggedIn = auth.isAuthenticated;
      final loc = state.matchedLocation;

      final isPublic = loc == '/login' ||
          loc.startsWith('/forgot-password') ||
          loc.startsWith('/reset-password');

      if (!isLoggedIn && !isPublic) return '/login';
      if (isLoggedIn && loc == '/login') {
        if (auth.user?.forcePasswordChange == true) return '/change-password';
        return '/dashboard';
      }
      return null;
    },
    routes: [
      // Public routes (no shell/nav)
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
        path: '/change-password',
        builder: (_, state) => ChangePasswordPage(
          forced: state.uri.queryParameters['forced'] == 'true',
        ),
      ),

      // Protected routes (wrapped in AppShell with sidebar)
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/tasks', builder: (_, __) => const TaskListPage()),
          // /tasks/create, /tasks/bulk-assign, /tasks/create-multi MUST come before /tasks/:id
          GoRoute(path: '/tasks/create', builder: (_, __) => const TaskCreatePage()),
          GoRoute(path: '/tasks/create-multi', builder: (_, __) => const TaskCreateMultiPage()),
          GoRoute(path: '/tasks/bulk-assign', builder: (_, __) => const TaskBulkAssignPage()),
          GoRoute(
            path: '/tasks/:id',
            builder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const TaskListPage();
              return TaskDetailPage(taskId: id);
            },
          ),
          GoRoute(path: '/users', builder: (_, __) => const UserListPage()),
          GoRoute(path: '/users/create', builder: (_, __) => const UserFormPage()),
          GoRoute(
            path: '/users/:id',
            builder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const UserListPage();
              return UserDetailPage(userId: id);
            },
          ),
          GoRoute(path: '/org', builder: (_, __) => const OrgManagePage()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsPage()),
          GoRoute(path: '/import-export', builder: (_, __) => const ImportExportPage()),
          GoRoute(path: '/system-config', builder: (_, __) => const SystemConfigPage()),
          GoRoute(path: '/hr-performance', builder: (_, __) => const HRPerformancePage()),
        ],
      ),
    ],
  );
});
