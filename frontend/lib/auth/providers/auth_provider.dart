import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/networking/dio_client.dart';
import '../../core/networking/token_service.dart';
import '../../core/storage/storage_service.dart';
import '../../features/config/providers/system_config_provider.dart';

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
    _restoreSession();
    ref.read(systemConfigProvider); // preload config
    return const AuthState();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> _restoreSession() async {
    final token = await StorageService.getToken();
    final userJson = await StorageService.getUserJson();
    if (token != null && userJson != null) {
      final user = UserModel.fromJson(jsonDecode(userJson));
      TokenService.instance.setToken(token);
      _dio.options.headers['Authorization'] = 'Bearer $token';
      state = AuthState(token: token, user: user);
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
      _dio.options.headers['Authorization'] = 'Bearer $token';
      state = AuthState(token: token, user: user);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Login failed';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
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
    TokenService.instance.setToken(null);
    _dio.options.headers.remove('Authorization');
    await StorageService.clearAll();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
