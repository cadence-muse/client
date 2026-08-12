import 'api_client.dart';

/// Maps to the `Register`/`Login`/`Logout` operations in
/// `lib/api/publicapi.yml`.
class PublicApi {
  PublicApi(this._client);

  final ApiClient _client;

  /// Returns the new user's id. Note the API doesn't log the user in on
  /// register, so callers should follow up with [login].
  Future<String> register({required String username, required String password}) async {
    final response = await _client.send(
      'POST',
      '/api/register',
      body: {'username': username, 'password': password},
      requireAuth: false,
    );
    return response!['id'] as String;
  }

  Future<void> login({required String username, required String password}) async {
    final response = await _client.send(
      'POST',
      '/api/login',
      body: {'username': username, 'password': password},
      requireAuth: false,
    );
    final token = response!['token'] as String;
    await _client.authSession.signIn(token);
  }

  /// Calls the API to invalidate the session, then always clears the local
  /// token, even if the request fails, so the user is signed out locally.
  Future<void> logout() async {
    try {
      await _client.send('POST', '/api/logout');
    } finally {
      await _client.authSession.signOut();
    }
  }
}
