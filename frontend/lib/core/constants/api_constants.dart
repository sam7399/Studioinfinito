import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.gemaromatics.com/api/v1';

  // Auth
  static const String login = '/auth/login';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/change-password';

  // Tasks
  static const String tasks = '/tasks';
  static String taskById(int id) => '/tasks/$id';
  static String taskActivities(int id) => '/tasks/$id/activities';
  static String taskReview(int id) => '/tasks/$id/review';
  static const String taskStats = '/tasks/stats/overview';

  // Users
  static const String users = '/users';
  static String userById(int id) => '/users/$id';
  static String userWorkload(int id) => '/users/$id/workload';
  static String userPerformance(int id) => '/users/$id/performance';

  // Import / Export
  static const String importUsers = '/import-export/users/import';
  static const String exportUsers = '/import-export/users/export';
  static const String importUsersSample = '/import-export/users/sample';
  static const String importTasks = '/import-export/tasks/import';
  static const String exportTasks = '/import-export/tasks/export';
  static const String importTasksSample = '/import-export/tasks/sample';

  // Org: Companies, Departments, Locations
  static const String companies = '/org/companies';
  static String companyById(int id) => '/org/companies/$id';
  static const String departments = '/org/departments';
  static String departmentById(int id) => '/org/departments/$id';
  static const String locations = '/org/locations';
  static String locationById(int id) => '/org/locations/$id';

  // Attachments
  static String taskAttachments(int id) => '/tasks/$id/attachments';
  static String taskAttachmentDownload(int taskId, int attachmentId) =>
      '/tasks/$taskId/attachments/$attachmentId/download';
  static String taskAttachmentDelete(int taskId, int attachmentId) =>
      '/tasks/$taskId/attachments/$attachmentId';

  // Bulk assign / bulk create
  static const String tasksBulkAssign = '/tasks/bulk-assign';
  static const String tasksBulkCreate = '/tasks/bulk-create';

  // Reports
  static const String reportWorklist = '/reports/worklist';
  static const String reportSummary = '/reports/summary';
  static const String reportExport = '/reports/export';
  static const String reportExcelExport = '/reports/export-excel';
  static const String reportEmail = '/reports/email';

  // Health
  static const String health = '/health';
}
