import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/networking/dio_client.dart';
import '../../core/networking/token_service.dart';
import '../../core/storage/storage_service.dart';
import '../../features/config/providers/system_config_provider.dart';
import '../../features/notifications/services/socket_service.dart';

/// Async provider that handles session initialization.
/// The router should wait for this to complete before allowing navigation
/// to prevent 401 errors from premature API calls.
final authInitializationProvider = FutureProvider<void>((ref) async {
  await ref.read(authProvider.notifier)._restoreSession();
});

class AuthState {
  final String? token;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.token,
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null;

  AuthState copyWith({
    String? token,
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearSession = false,
  }) {
    return AuthState(
      token: clearSession ? null : (token ?? this.token),
      user: clearSession ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    TokenService.instance.onUnauthorized = () => logout();
    // Start session restoration in the background.
    // The router should watch authInitializationProvider to wait for this.
    ref.read(authInitializationProvider);
    ref.read(systemConfigProvider); // preload config
    return const AuthState();
  }

  Dio get _dio => ref.read(dioProvider);

  /// Restore the session from local storage.
  /// This must be called asynchronously before making any API calls.
  /// Updates the internal state and TokenService when restoration is complete.
  Future<void> _restoreSession() async {
    try {
      final token = await StorageService.getToken();
      final userJson = await StorageService.getUserJson();
      if (token != null && userJson != null) {
        final user = UserModel.fromJson(jsonDecode(userJson));
        TokenService.instance.setToken(token);
        TokenService.instance.setUserId(user.id);
        _dio.options.headers['Authorization'] = 'Bearer $token';
        state = AuthState(token: token, user: user);

        // Initialize Socket.io after session restoration
        _initializeSocket(token);
      }
    } catch (e) {
      // If session restoration fails, clear any partial data
      await logout();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      final data = response.data['data'];
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      await StorageService.saveToken(token);
      await StorageService.saveUserJson(jsonEncode(user.toJson()));

      TokenService.instance.setToken(token);
      TokenService.instance.setUserId(user.id);
      _dio.options.headers['Authorization'] = 'Bearer $token';
      state = AuthState(token: token, user: user);

      // Initialize Socket.io after login
      _initializeSocket(token);

      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Login failed';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Initialize Socket.io connection for real-time updates
  void _initializeSocket(String token) {
    try {
      SocketService().initialize(ApiConstants.socketBaseUrl, token);
    } catch (e) {
      // Non-fatal — app works without real-time updates
    }
  }

  Future<void> clearForcePasswordChange() async {
    final user = state.user;
    if (user == null) return;
    final updated = UserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      companyId: user.companyId,
      departmentId: user.departmentId,
      locationId: user.locationId,
      phone: user.phone,
      isActive: user.isActive,
      forcePasswordChange: false,
    );
    await StorageService.saveUserJson(jsonEncode(updated.toJson()));
    state = state.copyWith(user: updated);
  }

  Future<void> logout() async {
    // Disconnect Socket.io on logout
    try {
      await SocketService().disconnect();
    } catch (_) {}

    TokenService.instance.setToken(null);
    TokenService.instance.setUserId(null);
    _dio.options.headers.remove('Authorization');
    await StorageService.clearAll();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
