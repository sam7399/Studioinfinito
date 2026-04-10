import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import 'token_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Auth interceptor: reads token at REQUEST time, not at provider build time.
  // This eliminates all timing issues with async session restoration.
  // Improves 401 error handling with proper logout on authentication failure.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = TokenService.instance.token;
        if (token != null && !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Handle 401 Unauthorized - token is expired or invalid
        if (error.response?.statusCode == 401) {
          // Prevent 401 errors on auth endpoints themselves (login, forgot-password, etc)
          final requestPath = error.requestOptions.path;
          final isAuthEndpoint = requestPath.contains('/auth/') && 
              !requestPath.contains('/auth/change-password');
          
          // If 401 is from a non-auth endpoint, the user needs to re-authenticate
          if (!isAuthEndpoint) {
            TokenService.instance.onUnauthorized?.call();
          }
        }
        
        // Pass error to caller for proper error handling
        handler.next(error);
      },
    ),
  );

  return dio;
});

final authDioProvider = Provider<Dio>((ref) => ref.watch(dioProvider));
