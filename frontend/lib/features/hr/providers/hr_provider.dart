import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/dio_client.dart';
import '../../../auth/providers/auth_provider.dart';

class HREmployeeRow {
  final int userId;
  final String name;
  final String? email;
  final String? designation;
  final String? empCode;
  final String? department;
  final String? location;
  final int totalTasks;
  final int openTasks;
  final int inProgressTasks;
  final int completedTasks;
  final int overdueTasks;
  final int reviewCount;
  final double? avgRating;
  final double? avgQualityScore;
  final double? avgTimelinessScore;
  final double? onTimeRate;

  HREmployeeRow({
    required this.userId,
    required this.name,
    this.email,
    this.designation,
    this.empCode,
    this.department,
    this.location,
    required this.totalTasks,
    required this.openTasks,
    required this.inProgressTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.reviewCount,
    this.avgRating,
    this.avgQualityScore,
    this.avgTimelinessScore,
    this.onTimeRate,
  });

  factory HREmployeeRow.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>? ?? {};
    final dept = (user['department'] as Map<String, dynamic>?)?['name'] as String?;
    final loc = (user['location'] as Map<String, dynamic>?)?['name'] as String?;
    return HREmployeeRow(
      userId: user['id'] as int? ?? 0,
      name: user['name'] as String? ?? '',
      email: user['email'] as String?,
      designation: user['designation'] as String?,
      empCode: user['emp_code'] as String?,
      department: dept,
      location: loc,
      totalTasks: (j['total_tasks'] as num?)?.toInt() ?? 0,
      openTasks: (j['open_tasks'] as num?)?.toInt() ?? 0,
      inProgressTasks: (j['in_progress_tasks'] as num?)?.toInt() ?? 0,
      completedTasks: (j['completed_tasks'] as num?)?.toInt() ?? 0,
      overdueTasks: (j['overdue_tasks'] as num?)?.toInt() ?? 0,
      reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
      avgRating: (j['avg_rating'] as num?)?.toDouble(),
      avgQualityScore: (j['avg_quality_score'] as num?)?.toDouble(),
      avgTimelinessScore: (j['avg_timeliness_score'] as num?)?.toDouble(),
      onTimeRate: (j['on_time_rate'] as num?)?.toDouble(),
    );
  }
}

// Key: department_id (null = all departments). Using int? avoids Map equality issues.
final hrMatrixProvider = FutureProvider.autoDispose.family<List<HREmployeeRow>, int?>((ref, departmentId) async {
  if (!ref.watch(authProvider.select((s) => s.isAuthenticated))) return [];
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/reports/hr-matrix',
      queryParameters: departmentId != null ? {'department_id': departmentId} : null);
  final List data = res.data['data'] ?? [];
  return data.map((j) => HREmployeeRow.fromJson(j as Map<String, dynamic>)).toList();
});
