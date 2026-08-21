import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import 'connectivity_provider.dart';
import 'offline_no_cache_exception.dart';
import '../cache/cache_service.dart';

part 'tracks_provider.g.dart';

/// `bandTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (family, keyed per band — mirrors [ProfileSyncedAt]'s
/// shape, see `profile_provider.dart`). Set from the cache's stored
/// timestamp on a cache hit (offline, or a failed online fetch falling back
/// to cache per D-03) and bumped unconditionally on every successful
/// [TrackListData._fetchAndCache]/[TrackListData.removeFromList].
@riverpod
class TrackListSyncedAt extends _$TrackListSyncedAt {
  @override
  DateTime? build(String bandId) => null;

  void set(DateTime? value) => state = value;
}

/// Online-first `GET /api/band/{bandId}/track/list` data (D-01/D-03/D-06),
/// keyed per band (family provider — mirrors [TrackListData]'s counterpart
/// [BandsListData] in `bands_provider.dart`).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load tracks" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches
/// it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
@riverpod
class TrackListData extends _$TrackListData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method
  /// ([removeFromList]). [refresh]/[_doRefresh] capture this before their
  /// network await and discard a fetched result if it changed while the
  /// fetch was in flight — otherwise a slower background refresh could
  /// silently revert a local edit that landed first (WR-02).
  int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build(String bandId) async {
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      try {
        return await _fetchAndCache(bandId);
      } catch (_) {
        // D-03: online but the fetch itself failed — fall back to cache
        // silently, the same as a true-offline cache hit.
        final cached = await cache.readBandTracks(bandId);
        if (cached != null) {
          ref
              .read(trackListSyncedAtProvider(bandId).notifier)
              .set(await cache.readBandTracksSyncedAt(bandId));
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readBandTracks(bandId);
    if (cached != null) {
      ref
          .read(trackListSyncedAtProvider(bandId).notifier)
          .set(await cache.readBandTracksSyncedAt(bandId));
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final tracks = await ref.read(publicApiProvider).listBandTracks(bandId);
    await ref.read(cacheServiceProvider).writeBandTracks(bandId, tracks);
    ref.read(trackListSyncedAtProvider(bandId).notifier).set(DateTime.now());
    return tracks;
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

/// `bandTrackDetail` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp (family, keyed per `(bandId,
/// trackId)` pair). Set from the cache's stored timestamp on a cache hit
/// (offline, or a failed online fetch falling back to cache per D-03) and
/// bumped unconditionally on every successful
/// [TrackDetailData._fetchAndCache]/[TrackDetailData.updateFields].
@riverpod
class TrackDetailSyncedAt extends _$TrackDetailSyncedAt {
  @override
  DateTime? build(String bandId, String trackId) => null;

  void set(DateTime? value) => state = value;
}

/// Online-first `GET /api/band/{bandId}/track/{trackId}` data
/// (D-01/D-03/D-06), keyed per `(bandId, trackId)` pair (family provider —
/// mirrors [TrackDetailData]'s counterpart [BandDetailData] in
/// `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not
/// consulted on the happy path); a failed online fetch falls back to cache
/// silently (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `TrackDetailScreen`.
@riverpod
class TrackDetailData extends _$TrackDetailData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method
  /// ([updateFields]). [refresh]/[_doRefresh] capture this before their
  /// network await and discard a fetched result if it changed while the
  /// fetch was in flight — otherwise a slower background refresh could
  /// silently revert a local edit that landed first (WR-02).
  int _version = 0;

  @override
  Future<Map<String, dynamic>> build(String bandId, String trackId) async {
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      try {
        return await _fetchAndCache(bandId, trackId);
      } catch (_) {
        // D-03: online but the fetch itself failed — fall back to cache
        // silently, the same as a true-offline cache hit.
        final cached = await cache.readBandTrackDetail(bandId, trackId);
        if (cached != null) {
          ref
              .read(trackDetailSyncedAtProvider(bandId, trackId).notifier)
              .set(await cache.readBandTrackDetailSyncedAt(bandId, trackId));
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readBandTrackDetail(bandId, trackId);
    if (cached != null) {
      ref
          .read(trackDetailSyncedAtProvider(bandId, trackId).notifier)
          .set(await cache.readBandTrackDetailSyncedAt(bandId, trackId));
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
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

/// `userTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (plain, non-family — mirrors [HomepageSyncedAt]'s
/// shape). Set from the cache's stored timestamp on a cache hit (offline, or
/// a failed online fetch falling back to cache per D-03) and bumped
/// unconditionally on every successful
/// [UserTracksListData._fetchAndCache].
@riverpod
class UserTracksSyncedAt extends _$UserTracksSyncedAt {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

/// Online-first `GET /api/track/list` data spanning every band the user
/// belongs to, optionally narrowed by [SelectedBandIdFilter] (D-01/D-03/D-06;
/// mirrors [TrackListData]'s online-first shape, but non-family — [build]
/// watches [selectedBandIdFilterProvider] directly, so changing the filter
/// automatically triggers a full rebuild with the new cache key/fetch).
///
/// This is the provider backing the cross-band Tracks tab (tab index 2) — a
/// `ref.listen(selectedTabIndexProvider, ...)` in `TracksScreen` invalidates
/// it on every re-selection of the Tracks tab (D-01), same shape as
/// `BandsScreen`'s wiring in `bands_screen.dart`.
@riverpod
class UserTracksListData extends _$UserTracksListData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method. Never mutated
  /// today (no local-mutation method exists on this provider) — preserved
  /// as-is per the pre-existing pattern established by [TrackListData]'s
  /// non-final counterpart, even though it is trivially always-true here.
  final int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final bandIdFilter = ref.watch(selectedBandIdFilterProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      try {
        return await _fetchAndCache(bandIdFilter);
      } catch (_) {
        // D-03: online but the fetch itself failed — fall back to cache
        // silently, the same as a true-offline cache hit.
        final cached = await cache.readUserTracks(bandIdFilter);
        if (cached != null) {
          ref
              .read(userTracksSyncedAtProvider.notifier)
              .set(await cache.readUserTracksSyncedAt(bandIdFilter));
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readUserTracks(bandIdFilter);
    if (cached != null) {
      ref
          .read(userTracksSyncedAtProvider.notifier)
          .set(await cache.readUserTracksSyncedAt(bandIdFilter));
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
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
