/// Holds the current auth token and user ID in memory.
/// Updated by AuthNotifier on login/logout/restore.
/// Read by Dio interceptor at request time.
class TokenService {
  TokenService._();
  static final TokenService instance = TokenService._();

  String? _token;
  int? _userId;
  void Function()? onUnauthorized;

  String? get token => _token;
  int? get userId => _userId;

  void setToken(String? token) {
    _token = token;
  }

  void setUserId(int? userId) {
    _userId = userId;
  }
}
