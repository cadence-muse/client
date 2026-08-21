import 'api_client.dart';

/// Maps to the `Register`/`Login`/`Logout` operations in
/// `lib/api/publicapi.yml`. Logging out calls the backend via [logout], but
/// [AuthSession.signOut] still always succeeds locally even if that call
/// fails — see its doc comment.
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

  /// Invalidates the current session token server-side (`Logout` in
  /// `publicapi.yml` — `POST /api/logout`, sessionAuth-protected, no body,
  /// `'200'` response has no content schema). Callers should treat this as
  /// best-effort: see [AuthSession.signOut], which always completes the
  /// local sign-out (token/cache clear) even if this call throws.
  Future<void> logout() async {
    await _client.send('POST', '/api/logout');
  }

  /// Changes the current user's password (`ChangeUserPassword` — `POST
  /// /api/me/password`). [currentPassword] is a client-first D-01 addition to
  /// `ChangeUserPasswordRequestBody` — the field is always sent, but backend
  /// validation of it may land separately. On a wrong [currentPassword], the
  /// server responds `400` with `ErrorCode.invalid_input` (never `401` —
  /// see `publicapi.yml`'s `BadRequest` response for this operation);
  /// callers should branch on `statusCode == 400 && code == 'invalid_input'`
  /// rather than checking for `401`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.send(
      'POST',
      '/api/me/password',
      body: {'currentPassword': currentPassword, 'password': newPassword},
    );
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
  Future<void> updateBand({
    required String bandId,
    required String name,
  }) async {
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
        'durationSeconds': ?durationSeconds,
        'tempo': ?tempo,
        'key': ?key,
        'notes': ?notes,
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

  /// Returns a band's setlists (`SetlistListItem` — id/name/tracksCount/
  /// durationSeconds + optional eventDate).
  Future<List<Map<String, dynamic>>> listBandSetlists(String bandId) async {
    final response = await _client.send(
      'GET',
      '/api/band/$bandId/setlist/list',
    );
    return (response!['items'] as List).cast<Map<String, dynamic>>();
  }

  /// Returns full setlist detail (`BandSetlist` — id, name, durationSeconds,
  /// tracks + optional eventLocation/eventDate).
  Future<Map<String, dynamic>> getSetlist(
    String bandId,
    String setlistId,
  ) async {
    final response = await _client.send(
      'GET',
      '/api/band/$bandId/setlist/$setlistId',
    );
    return response!;
  }

  /// Creates a new setlist in a band, optionally seeded with initial tracks.
  /// Returns the raw `CreateBandSetlistsResponseBody` map (`{id}`).
  Future<Map<String, dynamic>> createSetlist({
    required String bandId,
    required String name,
    String? eventLocation,
    String? eventDate,
    List<String>? trackIds,
  }) async {
    final response = await _client.send(
      'POST',
      '/api/band/$bandId/setlist',
      body: {
        'name': name,
        'eventLocation': ?eventLocation,
        'eventDate': ?eventDate,
        'trackIds': ?trackIds,
      },
    );
    return response!;
  }

  /// Updates a setlist's info. `UpdateBandSetlist`'s `'200'` response has no
  /// content schema (see `publicapi.yml`), so the client does not receive
  /// the updated `BandSetlist` back — callers merge their own submitted
  /// values into any local cache/state instead of trusting an echoed
  /// response (see `edit_setlist_screen.dart`, mirrors `updateBandTrack`).
  ///
  /// [name] is required — `EditSetlistScreen` is this method's only caller
  /// and always has it from its form. [eventLocation]/[eventDate] are always
  /// sent (mirrors `updateBandTrack`'s CR-02 fix), including an explicit
  /// `null` when the caller wants to clear a previously-set value: per
  /// `UpdateBandSetlistRequestBody`'s `nullable: true` schema, the server's
  /// merge/partial-update semantics treat an explicit JSON `null` as "clear
  /// this field," distinct from omitting the key entirely.
  Future<void> updateSetlist({
    required String bandId,
    required String setlistId,
    required String name,
    String? eventLocation,
    String? eventDate,
  }) async {
    await _client.send(
      'PUT',
      '/api/band/$bandId/setlist/$setlistId',
      body: {
        'name': name,
        'eventLocation': eventLocation,
        'eventDate': eventDate,
      },
    );
  }

  /// Deletes a setlist. Any band member may delete (no owner-only gate —
  /// see `04-02-PLAN.md`'s objective note); `'204'` no content (mirrors
  /// `deleteBandTrack`).
  Future<void> deleteSetlist(String bandId, String setlistId) async {
    await _client.send('DELETE', '/api/band/$bandId/setlist/$setlistId');
  }

  /// Adds one or more of the band's existing tracks to a setlist in a
  /// single bulk call (D-01, `AddSetlistTracksRequestBody`, `trackIds` max
  /// 100) — distinct from the pre-existing single-track `POST .../track`
  /// endpoint, which this plan does not use. `'204'` no content.
  Future<void> addSetlistTracks({
    required String bandId,
    required String setlistId,
    required List<String> trackIds,
  }) async {
    await _client.send(
      'POST',
      '/api/band/$bandId/setlist/$setlistId/tracks',
      body: {'trackIds': trackIds},
    );
  }

  /// Removes a single track from a setlist (D-13). `'204'` no content.
  Future<void> removeSetlistTrack({
    required String bandId,
    required String setlistId,
    required String trackId,
  }) async {
    await _client.send(
      'DELETE',
      '/api/band/$bandId/setlist/$setlistId/track/$trackId',
    );
  }

  /// Reorders a setlist's tracks (D-14). [trackIds] is a full-replace list
  /// of every track currently in the setlist, in the new order — not a
  /// partial diff (`ReorderSetlistTracksRequestBody`, max 100). `'204'` no
  /// content.
  Future<void> reorderSetlistTracks({
    required String bandId,
    required String setlistId,
    required List<String> trackIds,
  }) async {
    await _client.send(
      'PUT',
      '/api/band/$bandId/setlist/$setlistId/tracks/reorder',
      body: {'trackIds': trackIds},
    );
  }

  /// Returns setlists across every band the current user belongs to
  /// (`UserSetlistListItem` — id/name/tracksCount/durationSeconds/bandId/
  /// bandName + optional eventDate), optionally narrowed to a single band
  /// via [bandIdFilter]. Mirrors `listUserTracks` exactly (D-03, SETL-10).
  Future<List<Map<String, dynamic>>> listUserSetlists({
    String? bandIdFilter,
  }) async {
    final response = await _client.send(
      'GET',
      '/api/setlist/list',
      queryParameters: bandIdFilter == null ? null : {'bandId': bandIdFilter},
    );
    return (response!['items'] as List).cast<Map<String, dynamic>>();
  }
}
