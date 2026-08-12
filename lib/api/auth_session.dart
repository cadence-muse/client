import 'package:flutter/foundation.dart';

import 'token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Tracks the current auth token and whether the user is signed in.
///
/// Screens listen to this to decide whether to show the login page or the
/// app; [ApiClient] reads the token to authenticate requests and signs the
/// session out when a request comes back with 403 (session no longer valid).
class AuthSession extends ChangeNotifier {
  AuthSession({required this.tokenStorage});

  final TokenStorage tokenStorage;

  AuthStatus _status = AuthStatus.unknown;
  String? _token;

  AuthStatus get status => _status;
  String? get token => _token;

  /// Loads a previously persisted token, if any. Call once on app start.
  Future<void> restore() async {
    _token = await tokenStorage.read();
    _status = _token == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> signIn(String token) async {
    _token = token;
    _status = AuthStatus.authenticated;
    await tokenStorage.write(token);
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_status == AuthStatus.unauthenticated) return;
    _token = null;
    _status = AuthStatus.unauthenticated;
    await tokenStorage.delete();
    notifyListeners();
  }
}
