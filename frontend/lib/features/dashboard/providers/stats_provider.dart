import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/dio_client.dart';
import '../../notifications/services/socket_service.dart';

class TaskStats {
  final int total;
  final int open;
  final int inProgress;
  final int pendingReview;
  final int finalized;
  final int overdue;

  const TaskStats({
    this.total = 0,
    this.open = 0,
    this.inProgress = 0,
    this.pendingReview = 0,
    this.finalized = 0,
    this.overdue = 0,
  });

  factory TaskStats.fromJson(Map<String, dynamic> json) {
    // API returns: { total_tasks, status_counts: {open, in_progress, ...}, priority_counts: {...} }
    final statusCounts = json['status_counts'] as Map<String, dynamic>? ?? {};
    final total = (json['total_tasks'] as num?)?.toInt() ?? 0;
    return TaskStats(
      total: total,
      open: (statusCounts['open'] as num?)?.toInt() ?? 0,
      inProgress: (statusCounts['in_progress'] as num?)?.toInt() ?? 0,
      pendingReview: (statusCounts['complete_pending_review'] as num?)?.toInt() ?? 0,
      finalized: (statusCounts['finalized'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue_tasks'] as num?)?.toInt() ?? 0,
    );
  }
}

// Dashboard stats (no filters) — auto-refreshes on task updates via socket
final statsProvider = FutureProvider<TaskStats>((ref) async {
  final dio = ref.watch(dioProvider);

  // Listen for task update events to auto-refresh stats
  final completer = Completer<void>();
  final socketService = SocketService();
  final disposeListener = socketService.onTaskUpdate((_) {
    // Invalidate this provider so it re-fetches
    ref.invalidateSelf();
  });
  ref.onDispose(disposeListener);

  try {
    final response = await dio.get(ApiConstants.taskStats);
    return TaskStats.fromJson(response.data['data'] ?? {});
  } catch (_) {
    return const TaskStats();
  }
});

// Filtered stats for reports page — key is query string to avoid Map equality bug
final filteredStatsProvider =
    FutureProvider.family<TaskStats, String>((ref, queryString) async {
  final dio = ref.watch(dioProvider);
  try {
    // Parse key=value&key=value back into a map
    final params = queryString.isEmpty
        ? null
        : Map.fromEntries(queryString.split('&').map((e) {
            final kv = e.split('=');
            return MapEntry(kv[0], kv.length > 1 ? kv[1] : '');
          }));
    final response = await dio.get(ApiConstants.taskStats, queryParameters: params);
    return TaskStats.fromJson(response.data['data'] ?? {});
  } catch (_) {
    return const TaskStats();
  }
});
