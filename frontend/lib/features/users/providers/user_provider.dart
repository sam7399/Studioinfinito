import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/models/user_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/networking/dio_client.dart';
import '../../notifications/services/socket_service.dart';

class UserListState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;
  final int page;
  final bool hasMore;
  final int total;

  const UserListState({
    this.users = const [],
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
    this.total = 0,
  });

  UserListState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? error,
    int? page,
    bool? hasMore,
    int? total,
  }) {
    return UserListState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
    );
  }
}

class UserNotifier extends Notifier<UserListState> {
  void Function()? _disposeSocketListener;
  Timer? _debounceTimer;

  @override
  UserListState build() {
    // Setup socket listener for real-time user updates
    _setupSocketListeners();

    // Setup polling fallback
    _setupPollingFallback();

    // Initial fetch
    fetchUsers();

    // Cleanup on dispose
    ref.onDispose(() {
      _disposeSocketListener?.call();
      _debounceTimer?.cancel();
    });

    return const UserListState();
  }

  Dio get _dio => ref.read(dioProvider);

  /// Setup Socket.io listeners for real-time user updates
  void _setupSocketListeners() {
    final socketService = SocketService();

    _disposeSocketListener = socketService.onUserUpdate((data) {
      // Debounce rapid updates
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        fetchUsers(reset: true);
      });
    });
  }

  /// Register polling fallback tick for when WebSocket is disconnected
  void _setupPollingFallback() {
    final socketService = SocketService();
    socketService.onPollTick(() async {
      if (!state.isLoading) {
        await fetchUsers(reset: true);
      }
    });
  }

  Future<void> fetchUsers({Map<String, dynamic>? filters, bool reset = false}) async {
    if (state.isLoading) return;
    final page = reset ? 1 : state.page;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get(
        ApiConstants.users,
        queryParameters: {'page': page, 'limit': 20, ...?filters},
      );
      final List data = response.data['data']['users'];
      final users = data.map((j) => UserModel.fromJson(j as Map<String, dynamic>)).toList();
      final total = (response.data['data']['total'] as num?)?.toInt() ?? 0;
      final allUsers = reset ? users : [...state.users, ...users];
      state = state.copyWith(
        users: allUsers,
        isLoading: false,
        page: page + 1,
        hasMore: allUsers.length < total,
        total: total,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] ?? 'Failed to load users',
      );
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      await _dio.post(ApiConstants.users, data: data);
      await fetchUsers(reset: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: e.response?.data?['message'] ?? 'Failed to create user');
      return false;
    }
  }

  Future<bool> toggleActive(int userId, bool currentlyActive) async {
    try {
      await _dio.put(ApiConstants.userById(userId), data: {'is_active': !currentlyActive});
      // Re-fetch the updated list to get fresh data
      await fetchUsers(reset: true);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> deleteUser(int userId) async {
    try {
      await _dio.delete(ApiConstants.userById(userId));
      state = state.copyWith(
        users: state.users.where((u) => u.id != userId).toList(),
        total: state.total - 1,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: e.response?.data?['message'] ?? 'Failed to delete user');
      return false;
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, UserListState>(UserNotifier.new);
