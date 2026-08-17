import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import '../cache/cache_service.dart';

part 'tracks_provider.g.dart';

/// Cache-first `GET /api/band/{bandId}/track/list` data, keyed per band
/// (family provider — mirrors [BandsListData]'s cache-first shape, see
/// `bands_provider.dart`).
///
/// On [build], cached data (if present) is returned immediately with a
/// background refresh kicked off silently (no loading spinner, no error
/// surfaced if the background refresh fails). With no cache, the network
/// fetch happens inline and any [ApiException] becomes an [AsyncError],
/// which is what drives the "Couldn't load tracks" + Retry error state.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
/// `bandTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (family, keyed per band — mirrors [ProfileSyncedAt]'s
/// shape, see `profile_provider.dart`). Set on a cache hit (from the
/// pre-existing cached value) and bumped unconditionally on every successful
/// [TrackListData._fetchAndCache]/[TrackListData.removeFromList] — never on
/// a failed background refresh, since `_refresh()`'s catch branch never
/// reaches that call.
@riverpod
class TrackListSyncedAt extends _$TrackListSyncedAt {
  @override
  DateTime? build(String bandId) => null;

  void set(DateTime? value) => state = value;
}

@riverpod
class TrackListData extends _$TrackListData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method.
  /// [_refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// edit that landed first (WR-02).
  int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build(String bandId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBandTracks(bandId);
    if (cached != null) {
      ref
          .read(trackListSyncedAtProvider(bandId).notifier)
          .set(await cache.readBandTracksSyncedAt(bandId));
      unawaited(_refresh(bandId));
      return cached;
    }
    return _fetchAndCache(bandId);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final tracks = await ref.read(publicApiProvider).listBandTracks(bandId);
    await ref.read(cacheServiceProvider).writeBandTracks(bandId, tracks);
    ref.read(trackListSyncedAtProvider(bandId).notifier).set(DateTime.now());
    return tracks;
  }

  /// Silent background refresh fired from [build] on a cache hit. Never
  /// surfaces an error — a failed background refresh just leaves the
  /// currently-cached data displayed.
  Future<void> _refresh(String bandId) async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Keep showing cached data.
    }
  }

  /// User-initiated refresh (e.g. the refresh button/pull-to-refresh).
  /// Deduplicates concurrent calls so tapping refresh twice in quick
  /// succession triggers exactly one network request.
  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
      // Otherwise silently keep the last good data visible.
    }
  }

  /// Removes [trackId] from the cached list in-place after a successful
  /// [PublicApi.deleteBandTrack] call, mirroring
  /// [BandsListData.renameBand]'s direct-state-patch shape but filtering the
  /// deleted id out instead of patching it. No-ops if there's no data to
  /// patch (e.g. called while still loading or in an error state).
  void removeFromList(String trackId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final filtered = [
      for (final track in current)
        if (track['id'] != trackId) track,
    ];
    _version++;
    state = AsyncData(filtered);
    unawaited(ref.read(cacheServiceProvider).writeBandTracks(bandId, filtered));
    ref.read(trackListSyncedAtProvider(bandId).notifier).set(DateTime.now());
  }
}

/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
/// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
/// cache-first shape, see `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// tracks" + Retry error state).
/// `bandTrackDetail` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp (family, keyed per `(bandId,
/// trackId)` pair). Set on a cache hit (from the pre-existing cached value)
/// and bumped unconditionally on every successful
/// [TrackDetailData._fetchAndCache]/[TrackDetailData.updateFields] — never
/// on a failed background refresh, since `_refresh()`'s catch branch never
/// reaches that call.
@riverpod
class TrackDetailSyncedAt extends _$TrackDetailSyncedAt {
  @override
  DateTime? build(String bandId, String trackId) => null;

  void set(DateTime? value) => state = value;
}

@riverpod
class TrackDetailData extends _$TrackDetailData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method.
  /// [_refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// edit that landed first (WR-02).
  int _version = 0;

  @override
  Future<Map<String, dynamic>> build(String bandId, String trackId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBandTrackDetail(bandId, trackId);
    if (cached != null) {
      ref
          .read(trackDetailSyncedAtProvider(bandId, trackId).notifier)
          .set(await cache.readBandTrackDetailSyncedAt(bandId, trackId));
      unawaited(_refresh(bandId, trackId));
      return cached;
    }
    return _fetchAndCache(bandId, trackId);
  }

  Future<Map<String, dynamic>> _fetchAndCache(
    String bandId,
    String trackId,
  ) async {
    final track = await ref
        .read(publicApiProvider)
        .getBandTrack(bandId, trackId);
    await ref
        .read(cacheServiceProvider)
        .writeBandTrackDetail(bandId, trackId, track);
    ref
        .read(trackDetailSyncedAtProvider(bandId, trackId).notifier)
        .set(DateTime.now());
    return track;
  }

  /// Silent background refresh fired from [build] on a cache hit. Never
  /// surfaces an error — a failed background refresh just leaves the
  /// currently-cached data displayed.
  Future<void> _refresh(String bandId, String trackId) async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId, trackId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Keep showing cached data.
    }
  }

  /// User-initiated refresh (e.g. the refresh button/pull-to-refresh).
  /// Deduplicates concurrent calls so tapping refresh twice in quick
  /// succession triggers exactly one network request.
  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId, trackId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
      // Otherwise silently keep the last good data visible.
    }
  }

  /// Merges [patch] into the currently cached track-detail map after a
  /// successful [PublicApi.updateBandTrack] call, without an additional
  /// network fetch (`UpdateBandTrack`'s `'200'` response has no body to
  /// refetch-and-trust — see `edit_track_screen.dart`, mirrors
  /// [BandDetailData.updateName]). No-ops if there's no data to merge into
  /// (e.g. called while still loading or in an error state).
  Future<void> updateFields(Map<String, dynamic> patch) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = {...current, ...patch};
    _version++;
    state = AsyncData(updated);
    await ref
        .read(cacheServiceProvider)
        .writeBandTrackDetail(bandId, trackId, updated);
    ref
        .read(trackDetailSyncedAtProvider(bandId, trackId).notifier)
        .set(DateTime.now());
  }
}

/// The band the global Tracks tab's list is currently filtered to; `null`
/// means "all bands". Plain (non-family) provider — its notifier's `state`
/// is set directly by `TracksScreen`'s filter dropdown.
@riverpod
class SelectedBandIdFilter extends _$SelectedBandIdFilter {
  @override
  String? build() => null;

  /// Sets the filter (`null` = all bands). A public method instead of the
  /// literal `notifier.state = value` instruction — the latter fails
  /// `flutter analyze` (`invalid_use_of_protected_member`) when called from
  /// outside the notifier itself, per the same pattern established by
  /// `BandsListData.setBands()` (02-03).
  void setFilter(String? bandId) => state = bandId;
}

/// Cache-first `GET /api/track/list` data spanning every band the user
/// belongs to, optionally narrowed by [SelectedBandIdFilter] (mirrors
/// [TrackListData]'s cache-first shape, but non-family — [build] watches
/// [selectedBandIdFilterProvider] directly, so changing the filter
/// automatically triggers a full rebuild with the new cache key/fetch).
/// `userTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (plain, non-family — mirrors [HomepageSyncedAt]'s
/// shape). Set on a cache hit (from the pre-existing cached value) and
/// bumped unconditionally on every successful
/// [UserTracksListData._fetchAndCache] — never on a failed background
/// refresh, since `_refresh()`'s catch branch never reaches that call.
@riverpod
class UserTracksSyncedAt extends _$UserTracksSyncedAt {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

@riverpod
class UserTracksListData extends _$UserTracksListData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method.
  /// [_refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// edit that landed first (WR-02).
  final int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final bandIdFilter = ref.watch(selectedBandIdFilterProvider);
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readUserTracks(bandIdFilter);
    if (cached != null) {
      ref
          .read(userTracksSyncedAtProvider.notifier)
          .set(await cache.readUserTracksSyncedAt(bandIdFilter));
      unawaited(_refresh(bandIdFilter));
      return cached;
    }
    return _fetchAndCache(bandIdFilter);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(
    String? bandIdFilter,
  ) async {
    final tracks = await ref
        .read(publicApiProvider)
        .listUserTracks(bandIdFilter: bandIdFilter);
    await ref.read(cacheServiceProvider).writeUserTracks(bandIdFilter, tracks);
    ref.read(userTracksSyncedAtProvider.notifier).set(DateTime.now());
    return tracks;
  }

  /// Silent background refresh fired from [build] on a cache hit. Never
  /// surfaces an error — a failed background refresh just leaves the
  /// currently-cached data displayed.
  Future<void> _refresh(String? bandIdFilter) async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandIdFilter);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Keep showing cached data.
    }
  }

  /// User-initiated refresh (e.g. the refresh button/pull-to-refresh).
  /// Deduplicates concurrent calls so tapping refresh twice in quick
  /// succession triggers exactly one network request.
  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    final bandIdFilter = ref.read(selectedBandIdFilterProvider);
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandIdFilter);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
      // Otherwise silently keep the last good data visible.
    }
  }
}
