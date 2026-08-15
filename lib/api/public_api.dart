import 'api_client.dart';

/// Maps to the `Register`/`Login` operations in `lib/api/publicapi.yml`.
/// Logging out just drops the local token, see [AuthSession.signOut].
class PublicApi {
  PublicApi(this._client);

  final ApiClient _client;

  /// Returns the new user's id. Note the API doesn't log the user in on
  /// register, so callers should follow up with [login].
  Future<String> register({
    required String username,
    required String password,
  }) async {
    final response = await _client.send(
      'POST',
      '/api/register',
      body: {'username': username, 'password': password},
      requireAuth: false,
    );
    return response!['id'] as String;
  }

  /// Returns the session token. Callers are responsible for persisting it
  /// (e.g. via `authSessionProvider.notifier.signIn`), see [AuthSession.signOut].
  Future<String> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.send(
      'POST',
      '/api/login',
      body: {'username': username, 'password': password},
      requireAuth: false,
    );
    return response!['token'] as String;
  }
}
