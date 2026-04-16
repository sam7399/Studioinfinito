import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/dio_client.dart';
import '../../notifications/services/socket_service.dart';

class TaskListState {
  final List<TaskModel> tasks;
  final bool isLoading;
  final String? error;
  final int page;
  final bool hasMore;

  const TaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  TaskListState copyWith({
    List<TaskModel>? tasks,
    bool? isLoading,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class TaskNotifier extends Notifier<TaskListState> {
  void Function()? _disposeSocketListener;
  Timer? _debounceTimer;

  @override
  TaskListState build() {
    // Setup socket listener for real-time task updates
    _setupSocketListeners();

    // Setup polling fallback
    _setupPollingFallback();

    // Initial fetch
    Future.microtask(() => fetchTasks());

    // Cleanup on dispose
    ref.onDispose(() {
      _disposeSocketListener?.call();
      _debounceTimer?.cancel();
    });

    return const TaskListState(isLoading: false);
  }

  Dio get _dio => ref.read(dioProvider);

  /// Setup Socket.io listeners for real-time task updates
  void _setupSocketListeners() {
    final socketService = SocketService();

    _disposeSocketListener = socketService.onTaskUpdate((data) {
      // Debounce rapid updates (e.g. bulk operations)
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        fetchTasks(reset: true);
      });
    });
  }

  /// Register polling fallback tick for when WebSocket is disconnected
  void _setupPollingFallback() {
    final socketService = SocketService();
    socketService.onPollTick(() async {
      // Only refresh if not already loading
      if (!state.isLoading) {
        await fetchTasks(reset: true);
      }
    });
  }

  Future<void> fetchTasks(
      {Map<String, dynamic>? filters, bool reset = false}) async {
    if (state.isLoading) return;

    final page = reset ? 1 : state.page;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get(
        ApiConstants.tasks,
        queryParameters: {
          'page': page,
          'limit': 20,
          ...?filters,
        },
      );

      final dynamic body = response.data;
      if (body is! Map) throw Exception('Unexpected response: $body');
      final dynamic inner = body['data'];
      if (inner is! Map) throw Exception('Missing data field: $body');
      final List data = (inner['tasks'] as List?) ?? [];
      final tasks = data
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
      final allTasks = reset ? tasks : [...state.tasks, ...tasks];

      state = state.copyWith(
        tasks: allTasks,
        isLoading: false,
        page: page + 1,
        hasMore: allTasks.length < total,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ??
            'Failed to load tasks: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load tasks: $e',
      );
    }
  }

  Future<TaskModel?> getTask(int id) async {
    try {
      final response = await _dio.get(ApiConstants.taskById(id));
      return TaskModel.fromJson(response.data['data']);
    } on DioException {
      return null;
    }
  }

  /// Returns the created task ID on success, throws Exception with message on failure.
  Future<int> createTask(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(ApiConstants.tasks, data: data);
      final taskId = response.data['data']['id'] as int;
      await fetchTasks(reset: true);
      return taskId;
    } on DioException catch (e) {
      String msg;
      if (e.response?.data != null) {
        // Server returned a response — use its message
        msg = e.response!.data['message'] as String? ??
            'Server error (${e.response!.statusCode})';
        // If validation errors array is present, append first detail
        final errors = e.response!.data['errors'];
        if (errors is List && errors.isNotEmpty) {
          final detail = (errors.first as Map?)?.values.first?.toString() ?? '';
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
      await fetchTasks(reset: true);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> deleteTask(int id) async {
    try {
      await _dio.delete(ApiConstants.taskById(id));
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != id).toList(),
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> reopenTask(int id, String comment) async {
    try {
      await _dio.post(ApiConstants.taskReopen(id), data: {'comment': comment});
      await fetchTasks(reset: true);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> submitReview(int id, Map<String, dynamic> data) async {
    try {
      await _dio.post(ApiConstants.taskReview(id), data: data);
      await fetchTasks(reset: true);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Review failed';
      state = state.copyWith(error: msg.toString());
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
      await _dio
          .delete(ApiConstants.taskAttachmentDelete(taskId, attachmentId));
      return true;
    } on DioException {
      return false;
    }
  }
}

final taskProvider =
    NotifierProvider<TaskNotifier, TaskListState>(TaskNotifier.new);
