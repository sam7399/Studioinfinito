import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/dio_client.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../notifications/services/socket_service.dart';

// ── Per-tab data ──────────────────────────────────────────────────────────────

class TabTaskData {
  final List<TaskModel> tasks;
  final bool isLoading;
  final String? error;
  final int page;
  final bool hasMore;
  final bool initialized;
  final bool stale; // needs refresh when next activated

  const TabTaskData({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
    this.initialized = false,
    this.stale = false,
  });

  TabTaskData copyWith({
    List<TaskModel>? tasks,
    bool? isLoading,
    String? error,
    int? page,
    bool? hasMore,
    bool? initialized,
    bool? stale,
    bool clearError = false,
  }) {
    return TabTaskData(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      initialized: initialized ?? this.initialized,
      stale: stale ?? this.stale,
    );
  }

  TabTaskData get reset => const TabTaskData();
}

// ── Full list state ───────────────────────────────────────────────────────────

class TaskListState {
  final int activeTab; // 0 = Assigned to Me, 1 = Assigned by Me
  final TabTaskData assignedToMe;
  final TabTaskData assignedByMe;

  // Shared filters (persist across tab switches)
  final String searchQuery;
  final String sortBy;
  final String sortOrder; // 'asc' | 'desc'
  final String? statusFilter;
  final String? priorityFilter;
  final DateTime? dueDateFrom;
  final DateTime? dueDateTo;

  const TaskListState({
    this.activeTab = 0,
    this.assignedToMe = const TabTaskData(),
    this.assignedByMe = const TabTaskData(),
    this.searchQuery = '',
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
    this.statusFilter,
    this.priorityFilter,
    this.dueDateFrom,
    this.dueDateTo,
  });

  TaskListState copyWith({
    int? activeTab,
    TabTaskData? assignedToMe,
    TabTaskData? assignedByMe,
    String? searchQuery,
    String? sortBy,
    String? sortOrder,
    String? statusFilter,
    String? priorityFilter,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
    bool clearStatusFilter = false,
    bool clearPriorityFilter = false,
    bool clearDueDateFrom = false,
    bool clearDueDateTo = false,
  }) {
    return TaskListState(
      activeTab: activeTab ?? this.activeTab,
      assignedToMe: assignedToMe ?? this.assignedToMe,
      assignedByMe: assignedByMe ?? this.assignedByMe,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      priorityFilter: clearPriorityFilter ? null : (priorityFilter ?? this.priorityFilter),
      dueDateFrom: clearDueDateFrom ? null : (dueDateFrom ?? this.dueDateFrom),
      dueDateTo: clearDueDateTo ? null : (dueDateTo ?? this.dueDateTo),
    );
  }

  TabTaskData get activeTabData => activeTab == 0 ? assignedToMe : assignedByMe;
  List<TaskModel> get activeTasks => activeTabData.tasks;
  bool get isActiveLoading => activeTabData.isLoading;
  bool get activeHasMore => activeTabData.hasMore;
  String? get activeError => activeTabData.error;

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      statusFilter != null ||
      priorityFilter != null ||
      dueDateFrom != null ||
      dueDateTo != null ||
      sortBy != 'created_at' ||
      sortOrder != 'desc';
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class TaskNotifier extends Notifier<TaskListState> {
  Timer? _searchDebounce;
  Timer? _socketDebounce;
  void Function()? _disposeSocketListener;

  @override
  TaskListState build() {
    _setupSocketListeners();
    _setupPollingFallback();
    Future.microtask(() => _fetchTab(tab: 0, reset: true));
    ref.onDispose(() {
      _disposeSocketListener?.call();
      _searchDebounce?.cancel();
      _socketDebounce?.cancel();
    });
    return const TaskListState();
  }

  Dio get _dio => ref.read(dioProvider);
  int? get _currentUserId => ref.read(authProvider).user?.id;

  // ── Filter builder ──────────────────────────────────────────────────────────

  Map<String, dynamic> _buildQueryParams(int tab, int page) {
    final s = state;
    return {
      'page': page,
      'limit': 20,
      'sort_by': s.sortBy,
      'sort_order': s.sortOrder,
      if (s.searchQuery.isNotEmpty) 'search': s.searchQuery,
      if (s.statusFilter != null) 'status': s.statusFilter!,
      if (s.priorityFilter != null) 'priority': s.priorityFilter!,
      if (s.dueDateFrom != null)
        'due_date_from': s.dueDateFrom!.toIso8601String().split('T')[0],
      if (s.dueDateTo != null)
        'due_date_to': s.dueDateTo!.toIso8601String().split('T')[0],
      // Tab-specific: who is the relevant party
      if (tab == 0 && _currentUserId != null) 'assigned_to': _currentUserId!,
      if (tab == 1 && _currentUserId != null) 'created_by': _currentUserId!,
    };
  }

  // ── Core fetch ──────────────────────────────────────────────────────────────

  Future<void> _fetchTab({required int tab, bool reset = false}) async {
    // Guard: skip fetch if tab requires user context and userId is unavailable
    if ((tab == 0 || tab == 1) && _currentUserId == null) {
      final tabData = _tabData(tab);
      _setTabData(tab, tabData.copyWith(error: 'User context unavailable', isLoading: false));
      return;
    }

    final tabData = _tabData(tab);
    if (tabData.isLoading) return;

    final page = reset ? 1 : tabData.page;

    _setTabData(tab, tabData.copyWith(isLoading: true, clearError: true, stale: false));

    try {
      final response = await _dio.get(
        ApiConstants.tasks,
        queryParameters: _buildQueryParams(tab, page),
      );

      final body = response.data as Map;
      final inner = body['data'] as Map;
      final List raw = (inner['tasks'] as List?) ?? [];
      final tasks = raw
          .map((j) {
            try {
              return TaskModel.fromJson(j as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<TaskModel>()
          .toList();

      final pagination = (inner['pagination'] as Map<String, dynamic>?) ?? {};
      final total = (pagination['total'] as num?)?.toInt() ?? 0;
      final current = _tabData(tab); // re-read after await
      final merged = reset ? tasks : [...current.tasks, ...tasks];

      _setTabData(
        tab,
        current.copyWith(
          tasks: merged,
          isLoading: false,
          page: page + 1,
          hasMore: merged.length < total,
          initialized: true,
          stale: false,
        ),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString() ??
          'Failed to load tasks: ${e.message}';
      _setTabData(tab, _tabData(tab).copyWith(isLoading: false, error: msg));
    } catch (e) {
      _setTabData(
          tab, _tabData(tab).copyWith(isLoading: false, error: 'Error: $e'));
    }
  }

  // ── Tab helpers ─────────────────────────────────────────────────────────────

  TabTaskData _tabData(int tab) =>
      tab == 0 ? state.assignedToMe : state.assignedByMe;

  void _setTabData(int tab, TabTaskData data) {
    state = tab == 0
        ? state.copyWith(assignedToMe: data)
        : state.copyWith(assignedByMe: data);
  }

  void _markOtherTabStale() {
    final other = state.activeTab == 0 ? 1 : 0;
    _setTabData(other, _tabData(other).copyWith(stale: true));
  }

  void _refetchActiveTab() {
    _markOtherTabStale();
    _fetchTab(tab: state.activeTab, reset: true);
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> setTab(int tab) async {
    if (tab == state.activeTab) return;
    state = state.copyWith(activeTab: tab);
    final td = _tabData(tab);
    if (!td.initialized || td.stale) {
      await _fetchTab(tab: tab, reset: true);
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), _refetchActiveTab);
  }

  void setSort(String by, String order) {
    state = state.copyWith(sortBy: by, sortOrder: order);
    _refetchActiveTab();
  }

  void setStatusFilter(String? status) {
    state = status == null
        ? state.copyWith(clearStatusFilter: true)
        : state.copyWith(statusFilter: status);
    _refetchActiveTab();
  }

  void setPriorityFilter(String? priority) {
    state = priority == null
        ? state.copyWith(clearPriorityFilter: true)
        : state.copyWith(priorityFilter: priority);
    _refetchActiveTab();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      dueDateFrom: from,
      dueDateTo: to,
      clearDueDateFrom: from == null,
      clearDueDateTo: to == null,
    );
    _refetchActiveTab();
  }

  void clearFilters() {
    final currentTab = state.activeTab;
    state = TaskListState(
      activeTab: currentTab,
      assignedToMe: state.assignedToMe.copyWith(stale: currentTab != 0),
      assignedByMe: state.assignedByMe.copyWith(stale: currentTab != 1),
    );
    _fetchTab(tab: currentTab, reset: true);
  }

  void fetchMore() {
    final tab = state.activeTab;
    final td = _tabData(tab);
    if (td.hasMore && !td.isLoading) {
      _fetchTab(tab: tab);
    }
  }

  void refreshAll() {
    _fetchTab(tab: 0, reset: true);
    _fetchTab(tab: 1, reset: true);
  }

  // ── Socket / polling ────────────────────────────────────────────────────────

  void _setupSocketListeners() {
    final svc = SocketService();
    _disposeSocketListener = svc.onTaskUpdate((_) {
      _socketDebounce?.cancel();
      _socketDebounce = Timer(const Duration(milliseconds: 600), refreshAll);
    });
  }

  void _setupPollingFallback() {
    SocketService().onPollTick(() async {
      if (!state.assignedToMe.isLoading && !state.assignedByMe.isLoading) {
        refreshAll();
      }
    });
  }

  // ── Task detail operations (used by task_detail_page) ──────────────────────

  Future<TaskModel?> getTask(int id) async {
    try {
      final response = await _dio.get(ApiConstants.taskById(id));
      return TaskModel.fromJson(response.data['data']);
    } on DioException {
      return null;
    }
  }

  Future<int> createTask(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(ApiConstants.tasks, data: data);
      final taskId = response.data['data']['id'] as int;
      refreshAll();
      return taskId;
    } on DioException catch (e) {
      String msg;
      if (e.response?.data != null) {
        msg = e.response!.data['message'] as String? ??
            'Server error (${e.response!.statusCode})';
        final errors = e.response!.data['errors'];
        if (errors is List && errors.isNotEmpty) {
          final detail =
              (errors.first as Map?)?.values.first?.toString() ?? '';
          if (detail.isNotEmpty) msg = '$msg: $detail';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        msg = 'Request timed out. Check your connection and try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        msg = 'Cannot reach server. Check your internet connection.';
      } else {
        msg = 'Network error: ${e.message ?? e.type.name}';
      }
      throw Exception(msg);
    }
  }

  Future<bool> updateTask(int id, Map<String, dynamic> data) async {
    try {
      await _dio.put(ApiConstants.taskById(id), data: data);
      refreshAll();
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> deleteTask(int id) async {
    try {
      await _dio.delete(ApiConstants.taskById(id));
      // Remove from both tab lists immediately for snappy UI
      state = state.copyWith(
        assignedToMe: state.assignedToMe.copyWith(
          tasks: state.assignedToMe.tasks.where((t) => t.id != id).toList(),
        ),
        assignedByMe: state.assignedByMe.copyWith(
          tasks: state.assignedByMe.tasks.where((t) => t.id != id).toList(),
        ),
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> reopenTask(int id, String comment) async {
    try {
      await _dio.post(ApiConstants.taskReopen(id), data: {'comment': comment});
      refreshAll();
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> submitReview(int id, Map<String, dynamic> data) async {
    try {
      await _dio.post(ApiConstants.taskReview(id), data: data);
      refreshAll();
      return true;
    } on DioException catch (e) {
      final msg =
          e.response?.data?['message'] ?? e.message ?? 'Review failed';
      final activeTab = state.activeTab;
      if (activeTab == 0) {
        state = state.copyWith(
          assignedToMe: state.assignedToMe.copyWith(error: msg.toString()),
        );
      } else if (activeTab == 1) {
        state = state.copyWith(
          assignedByMe: state.assignedByMe.copyWith(error: msg.toString()),
        );
      }
      return false;
    }
  }

  Future<List<TaskActivity>> getTaskActivities(int id) async {
    try {
      final response = await _dio.get(ApiConstants.taskActivities(id));
      final List data = response.data['data'] ?? [];
      return data.map((j) => TaskActivity.fromJson(j)).toList();
    } on DioException {
      return [];
    }
  }

  Future<bool> uploadAttachment(
      int taskId, Uint8List bytes, String filename, String mimeType) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes,
            filename: filename, contentType: DioMediaType.parse(mimeType)),
      });
      await _dio.post(ApiConstants.taskAttachments(taskId), data: formData);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAttachments(int taskId) async {
    try {
      final response = await _dio.get(ApiConstants.taskAttachments(taskId));
      return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
    } on DioException {
      return [];
    }
  }

  Future<bool> deleteAttachment(int taskId, int attachmentId) async {
    try {
      await _dio.delete(ApiConstants.taskAttachmentDelete(taskId, attachmentId));
      return true;
    } on DioException {
      return false;
    }
  }
}

final taskProvider =
    NotifierProvider<TaskNotifier, TaskListState>(TaskNotifier.new);
