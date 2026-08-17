import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import '../cache/cache_service.dart';

part 'setlists_provider.g.dart';

/// Cache-first `GET /api/band/{bandId}/setlist/list` data, keyed per band
/// (family provider — mirrors [TrackListData]'s cache-first shape, see
/// `tracks_provider.dart`).
///
/// On [build], cached data (if present) is returned immediately with a
/// background refresh kicked off silently (no loading spinner, no error
/// surfaced if the background refresh fails). With no cache, the network
/// fetch happens inline and any [ApiException] becomes an [AsyncError],
/// which is what drives the "Failed to load setlists" + Retry error state.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
@riverpod
class SetlistListData extends _$SetlistListData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method.
  /// [_refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// mutation that landed first (WR-02).
  int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build(String bandId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBandSetlists(bandId);
    if (cached != null) {
      unawaited(_refresh(bandId));
      return cached;
    }
    return _fetchAndCache(bandId);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final setlists = await ref
        .read(publicApiProvider)
        .listBandSetlists(bandId);
    await ref.read(cacheServiceProvider).writeBandSetlists(bandId, setlists);
    return setlists;
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

  /// Removes [setlistId] from the cached list in-place after a successful
  /// [PublicApi.deleteSetlist] call, mirroring
  /// [TrackListData.removeFromList]'s direct-state-patch shape. No-ops if
  /// there's no data to patch (e.g. called while still loading or in an
  /// error state).
  void removeFromList(String setlistId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final filtered = [
      for (final setlist in current)
        if (setlist['id'] != setlistId) setlist,
    ];
    _version++;
    state = AsyncData(filtered);
    unawaited(
      ref.read(cacheServiceProvider).writeBandSetlists(bandId, filtered),
    );
  }
}

/// Cache-first `GET /api/band/{bandId}/setlist/{setlistId}` data, keyed per
/// `(bandId, setlistId)` pair (family provider — mirrors [TrackDetailData]'s
/// cache-first shape, see `tracks_provider.dart`).
///
/// Mirrors [SetlistListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Failed to load
/// setlists" + Retry error state).
@riverpod
class SetlistDetailData extends _$SetlistDetailData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method.
  /// [_refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// edit that landed first (WR-02).
  int _version = 0;

  @override
  Future<Map<String, dynamic>> build(String bandId, String setlistId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readSetlistDetail(bandId, setlistId);
    if (cached != null) {
      unawaited(_refresh(bandId, setlistId));
      return cached;
    }
    return _fetchAndCache(bandId, setlistId);
  }

  Future<Map<String, dynamic>> _fetchAndCache(
    String bandId,
    String setlistId,
  ) async {
    final setlist = await ref
        .read(publicApiProvider)
        .getSetlist(bandId, setlistId);
    await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, setlist);
    return setlist;
  }

  /// Silent background refresh fired from [build] on a cache hit. Never
  /// surfaces an error — a failed background refresh just leaves the
  /// currently-cached data displayed.
  Future<void> _refresh(String bandId, String setlistId) async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId, setlistId);
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
      final fresh = await _fetchAndCache(bandId, setlistId);
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

  /// Merges [patch] into the currently cached setlist-detail map after a
  /// successful [PublicApi.updateSetlist] call, without an additional
  /// network fetch (`UpdateBandSetlist`'s `'200'` response has no body to
  /// refetch-and-trust — see `edit_setlist_screen.dart`, mirrors
  /// [TrackDetailData.updateFields]). No-ops if there's no data to merge
  /// into (e.g. called while still loading or in an error state).
  Future<void> updateFields(Map<String, dynamic> patch) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = {...current, ...patch};
    _version++;
    state = AsyncData(updated);
    await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, updated);
  }

  /// Patches the cached setlist detail's `tracks` order in-place after a
  /// successful [PublicApi.reorderSetlistTracks] call (D-14), without an
  /// additional network fetch — reordering doesn't change `durationSeconds`
  /// or track count, unlike [SetlistDetailScreen]'s add/remove flows, so a
  /// local patch is safe here. [trackIds] is the complete new order (every
  /// track currently in the setlist); each id's full existing track map
  /// (title/artist/durationSeconds) is preserved, only the order changes.
  /// No-ops if there's no data to patch (e.g. called while still loading or
  /// in an error state).
  Future<void> reorderTracks(List<String> trackIds) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final oldTracks = (current['tracks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final trackMap = {
      for (final t in oldTracks) t['trackId'] as String: t,
    };
    final reordered = [
      for (final id in trackIds)
        if (trackMap.containsKey(id)) trackMap[id]!,
    ];
    _version++;
    final updated = {...current, 'tracks': reordered};
    state = AsyncData(updated);
    await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, updated);
  }
}
