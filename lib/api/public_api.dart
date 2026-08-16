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

  /// Deletes a band. Server-enforced owner-only (see `Remove band` in
  /// `publicapi.yml`); `'204'` no content. The client-side owner gate (see
  /// `band_detail_screen.dart`'s `_isOwner`) only hides the UI path — the
  /// server remains the authoritative enforcer.
  Future<void> deleteBand(String bandId) async {
    await _client.send('DELETE', '/api/band/$bandId');
  }

  /// Removes a member from a band. Serves both self-leave (any member may
  /// remove themselves) and owner-initiated removal (owner may remove
  /// anybody) — see `RemoveBandMember` in `publicapi.yml`; `'204'` no
  /// content. The only difference between the two call sites is which
  /// [userId] is passed.
  Future<void> removeMember({
    required String bandId,
    required String userId,
  }) async {
    await _client.send('DELETE', '/api/band/$bandId/remove-member/$userId');
  }

  /// Returns a band's tracks (`TrackListItem` — id/title/artist +
  /// optional durationSeconds).
  Future<List<Map<String, dynamic>>> listBandTracks(String bandId) async {
    final response = await _client.send('GET', '/api/band/$bandId/track/list');
    return (response!['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Returns full track detail (`BandTrack` — id, title, artist,
  /// durationSeconds, tempo, key, notes).
  Future<Map<String, dynamic>> getBandTrack(
    String bandId,
    String trackId,
  ) async {
    final response = await _client.send(
      'GET',
      '/api/band/$bandId/track/$trackId',
    );
    return response!;
  }

  /// Creates a new track in a band. Returns the raw
  /// `CreateBandTrackResponseBody` map (`{id}`).
  Future<Map<String, dynamic>> createBandTrack({
    required String bandId,
    required String title,
    required String artist,
    int? durationSeconds,
    int? tempo,
    String? key,
    String? notes,
  }) async {
    final response = await _client.send(
      'POST',
      '/api/band/$bandId/track',
      body: {
        'title': title,
        'artist': artist,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (tempo != null) 'tempo': tempo,
        if (key != null) 'key': key,
        if (notes != null) 'notes': notes,
      },
    );
    return response!;
  }

  /// Updates a track's info. `UpdateBandTrack`'s `'200'` response has no
  /// content schema (see `publicapi.yml`), so the client does not receive the
  /// updated `BandTrack` back — callers merge their own submitted values into
  /// any local cache/state instead of trusting an echoed response (see
  /// `edit_track_screen.dart`, mirrors `updateBand`).
  ///
  /// [title]/[artist] are required — `EditTrackScreen` is this method's only
  /// caller and always has both from its form. [durationSeconds]/[tempo]/
  /// [key]/[notes] are always sent (CR-02 fix), including an explicit `null`
  /// when the caller wants to clear a previously-set value: per
  /// `UpdateBandTrackRequestBody`'s `nullable: true` schema, the server's
  /// merge/partial-update semantics treat an explicit JSON `null` as "clear
  /// this field," distinct from omitting the key entirely (which the old
  /// conditional-guard behavior did, silently preventing users from ever
  /// clearing a field). Contrast with [createBandTrack], which is
  /// intentionally unchanged — there is no "old value" to clear on create.
  Future<void> updateBandTrack({
    required String bandId,
    required String trackId,
    required String title,
    required String artist,
    int? durationSeconds,
    int? tempo,
    String? key,
    String? notes,
  }) async {
    await _client.send(
      'PUT',
      '/api/band/$bandId/track/$trackId',
      body: {
        'title': title,
        'artist': artist,
        'durationSeconds': durationSeconds,
        'tempo': tempo,
        'key': key,
        'notes': notes,
      },
    );
  }

  /// Deletes a track. Any band member may delete (no owner-only gate — see
  /// `03-02-PLAN.md`'s objective note); `'204'` no content (mirrors
  /// `deleteBand`).
  Future<void> deleteBandTrack(String bandId, String trackId) async {
    await _client.send('DELETE', '/api/band/$bandId/track/$trackId');
  }

  /// Returns tracks across every band the current user belongs to
  /// (`UserTrackListItem` — id/title/artist/durationSeconds/bandId/bandName),
  /// optionally narrowed to a single band via [bandIdFilter].
  Future<List<Map<String, dynamic>>> listUserTracks({
    String? bandIdFilter,
  }) async {
    final response = await _client.send(
      'GET',
      '/api/track/list',
      queryParameters: bandIdFilter == null ? null : {'bandId': bandIdFilter},
    );
    return (response!['items'] as List).cast<Map<String, dynamic>>();
  }
}
