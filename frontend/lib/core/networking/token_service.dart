/// Holds the current auth token in memory.
/// Updated by AuthNotifier on login/logout/restore.
/// Read by Dio interceptor at request time.
class TokenService {
  TokenService._();
  static final TokenService instance = TokenService._();

  String? _token;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }
}
