import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/approval_model.dart';
import '../services/approval_service.dart';
import '../../../core/networking/dio_client.dart';
import '../../notifications/services/socket_service.dart';

final _logger = Logger();

// ============================================================================
// SERVICE PROVIDERS
// ============================================================================

/// Provider for ApprovalService
final approvalServiceProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return ApprovalService(dio);
});

// ============================================================================
// STATE CLASSES
// ============================================================================

class PendingApprovalsState {
  final List<PendingApprovalModel> approvals;
  final int total;
  final int currentPage;
  final int itemsPerPage;
  final bool isLoading;
  final String? error;

  const PendingApprovalsState({
    this.approvals = const [],
    this.total = 0,
    this.currentPage = 1,
    this.itemsPerPage = 20,
    this.isLoading = false,
    this.error,
  });

  PendingApprovalsState copyWith({
    List<PendingApprovalModel>? approvals,
    int? total,
    int? currentPage,
    int? itemsPerPage,
    bool? isLoading,
    String? error,
  }) {
    return PendingApprovalsState(
      approvals: approvals ?? this.approvals,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get totalPages => (total / itemsPerPage).ceil();
  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
}

// ============================================================================
// NOTIFIERS
// ============================================================================

class PendingApprovalsNotifier extends Notifier<PendingApprovalsState> {
  late final ApprovalService _service;
  void Function()? _disposeSocketListener;
  Timer? _debounceTimer;

  @override
  PendingApprovalsState build() {
    _service = ref.watch(approvalServiceProvider);

    // Setup socket listener for real-time approval updates
    final socketService = SocketService();
    _disposeSocketListener = socketService.onApprovalUpdate((data) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        refreshPendingApprovals();
        ref.invalidate(pendingApprovalsCountProvider);
      });
    });

    ref.onDispose(() {
      _disposeSocketListener?.call();
      _debounceTimer?.cancel();
    });

    // Auto-fetch on build
    Future.microtask(() => fetchPendingApprovals());
    return const PendingApprovalsState();
  }

  Future<void> fetchPendingApprovals({
    int page = 1,
    String? priority,
    int? departmentId,
    bool reset = false,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _service.getPendingApprovals(
        page: page,
        limit: state.itemsPerPage,
        priority: priority,
        departmentId: departmentId,
      );

      final approvals = reset ? result.approvals : [...state.approvals, ...result.approvals];

      state = state.copyWith(
        approvals: approvals,
        total: result.total,
        currentPage: result.page,
        isLoading: false,
      );
    } on DioException catch (e) {
      _logger.e('Error fetching pending approvals', error: e);
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load pending approvals',
      );
    }
  }

  Future<void> refreshPendingApprovals() async {
    await fetchPendingApprovals(reset: true);
  }

  Future<void> nextPage({String? priority, int? departmentId}) async {
    if (!state.hasNextPage) return;
    await fetchPendingApprovals(
      page: state.currentPage + 1,
      priority: priority,
      departmentId: departmentId,
    );
  }

  Future<void> previousPage({String? priority, int? departmentId}) async {
    if (!state.hasPreviousPage) return;
    await fetchPendingApprovals(
      page: state.currentPage - 1,
      priority: priority,
      departmentId: departmentId,
    );
  }

  /// Approve a pending task and refresh the list
  Future<void> approveTask(int taskId, {String? comments}) async {
    try {
      await _service.approveTask(taskId, comments: comments);
      await refreshPendingApprovals();
      ref.invalidate(pendingApprovalsCountProvider);
    } on DioException catch (e) {
      _logger.e('Error approving task in notifier', error: e);
      rethrow;
    }
  }

  /// Reject a pending task and refresh the list
  Future<void> rejectTask(int taskId, String reason) async {
    try {
      await _service.rejectTask(taskId, reason);
      await refreshPendingApprovals();
      ref.invalidate(pendingApprovalsCountProvider);
    } on DioException catch (e) {
      _logger.e('Error rejecting task in notifier', error: e);
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for pending approvals list with pagination
final pendingApprovalsProvider = NotifierProvider<PendingApprovalsNotifier, PendingApprovalsState>(
  () => PendingApprovalsNotifier(),
);

/// Provider for pending approvals count (for badge)
final pendingApprovalsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(approvalServiceProvider);
  return service.getPendingApprovalsCount();
});

/// Provider for single approval details
final approvalDetailsProvider = FutureProvider.family<PendingApprovalModel?, int>((ref, taskId) async {
  final approvals = ref.watch(pendingApprovalsProvider).approvals;
  // Try to find in cached list first
  try {
    final approval = approvals.firstWhere((a) => a.task.id == taskId);
    return approval;
  } catch (e) {
    return null;
  }
});

/// Provider for approval history of a specific task
final approvalHistoryProvider = FutureProvider.family<List<TaskApprovalModel>, int>((ref, taskId) async {
  final service = ref.watch(approvalServiceProvider);
  return service.getApprovalHistory(taskId);
});

/// Provider for tasks submitted for approval by current user (requires task provider)
/// This is used to show status of tasks the user submitted for approval
class MyTaskApprovalStatusState {
  final Map<int, TaskApprovalModel?> taskApprovals;
  final bool isLoading;

  const MyTaskApprovalStatusState({
    this.taskApprovals = const {},
    this.isLoading = false,
  });

  MyTaskApprovalStatusState copyWith({
    Map<int, TaskApprovalModel?>? taskApprovals,
    bool? isLoading,
  }) {
    return MyTaskApprovalStatusState(
      taskApprovals: taskApprovals ?? this.taskApprovals,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MyTaskApprovalStatusNotifier extends Notifier<MyTaskApprovalStatusState> {
  late final ApprovalService _service;

  @override
  MyTaskApprovalStatusState build() {
    _service = ref.watch(approvalServiceProvider);
    return const MyTaskApprovalStatusState();
  }

  /// Check approval status for a specific task
  Future<TaskApprovalModel?> checkTaskApprovalStatus(int taskId) async {
    state = state.copyWith(isLoading: true);
    try {
      final history = await _service.getApprovalHistory(taskId);
      
      // Get the most recent approval record
      TaskApprovalModel? approval;
      if (history.isNotEmpty) {
        approval = history.reduce((a, b) => a.reviewedAt != null && b.reviewedAt != null
            ? (a.reviewedAt!.isAfter(b.reviewedAt!) ? a : b)
            : (a.reviewedAt != null ? a : b));
      }

      state = state.copyWith(
        taskApprovals: {...state.taskApprovals, taskId: approval},
        isLoading: false,
      );

      return approval;
    } catch (e) {
      _logger.e('Error checking task approval status', error: e);
      state = state.copyWith(isLoading: false);
      return null;
    }
  }

  /// Get cached approval status for a task
  TaskApprovalModel? getApprovalStatus(int taskId) {
    return state.taskApprovals[taskId];
  }
}

/// Provider for tracking approval status of user's own tasks
final myTaskApprovalStatusProvider = NotifierProvider<MyTaskApprovalStatusNotifier, MyTaskApprovalStatusState>(
  () => MyTaskApprovalStatusNotifier(),
);

// ============================================================================
// ACTION PROVIDERS
// ============================================================================

/// Provider for submitting a task for approval
final submitTaskForApprovalProvider = FutureProvider.family<ApprovalActionResponse, int>((ref, taskId) async {
  final service = ref.watch(approvalServiceProvider);
  final response = await service.submitForApproval(taskId);
  
  // Invalidate relevant providers after successful submission
  if (response.success) {
    // Refresh pending approvals count
    ref.invalidate(pendingApprovalsCountProvider);
    // Refresh approval status for this task
    ref.read(myTaskApprovalStatusProvider.notifier).checkTaskApprovalStatus(taskId);
  }
  
  return response;
});
