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

  /// Returns the current user's bands (`BandListItem` — id + name only).
  Future<List<Map<String, dynamic>>> listBands() async {
    final response = await _client.send('GET', '/api/band/list');
    return (response!['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Returns full band detail (`Band` — id, name, ownerId, members,
  /// inviteCode).
  Future<Map<String, dynamic>> getBand(String bandId) async {
    final response = await _client.send('GET', '/api/band/$bandId');
    return response!;
  }

  /// Creates a new band. Returns the raw `CreateBandResponseBody` map
  /// (`{id}`).
  Future<Map<String, dynamic>> createBand({required String name}) async {
    final response = await _client.send(
      'POST',
      '/api/band',
      body: {'name': name},
    );
    return response!;
  }

  /// Joins a band by invite code. `POST /api/band/join` has no response
  /// schema (see `publicapi.yml`), so the newly-joined band's id isn't
  /// returned here — callers resolve it client-side (see
  /// `join_band_dialog.dart`).
  Future<void> joinBand({required String inviteCode}) async {
    await _client.send(
      'POST',
      '/api/band/join',
      body: {'inviteCode': inviteCode.trim()},
    );
  }

  /// Updates a band's name. `UpdateBand`'s `'200'` response has no content
  /// schema (see `publicapi.yml`), so the client does not receive the
  /// updated `Band` back — callers merge their own submitted [name] into any
  /// local cache/state instead of trusting an echoed response (see
  /// `edit_band_screen.dart`).
  Future<void> updateBand({required String bandId, required String name}) async {
    await _client.send('PUT', '/api/band/$bandId', body: {'name': name});
  }
}
