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
/// D-04: `bandSetlists` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp (mirrors [ProfileSyncedAt], see
/// `profile_provider.dart`). Set on a cache hit (from the pre-existing
/// cached value) and bumped unconditionally on every successful
/// [SetlistListData._fetchAndCache]/[SetlistListData.removeFromList] write —
/// never on a failed background refresh, since `_refresh()`'s catch branch
/// never reaches that call.
@riverpod
class SetlistListSyncedAt extends _$SetlistListSyncedAt {
  @override
  DateTime? build(String bandId) => null;

  void set(DateTime? value) => state = value;
}

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
      ref
          .read(setlistListSyncedAtProvider(bandId).notifier)
          .set(await cache.readBandSetlistsSyncedAt(bandId));
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
    ref.read(setlistListSyncedAtProvider(bandId).notifier).set(DateTime.now());
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
    ref.read(setlistListSyncedAtProvider(bandId).notifier).set(DateTime.now());
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
/// D-04: `setlistDetail` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp (mirrors [SetlistListSyncedAt]).
/// Set on a cache hit (from the pre-existing cached value) and bumped
/// unconditionally on every successful [SetlistDetailData._fetchAndCache] /
/// [SetlistDetailData.updateFields] / [SetlistDetailData.reorderTracks]
/// write — never on a failed background refresh, since `_refresh()`'s catch
/// branch never reaches that call.
@riverpod
class SetlistDetailSyncedAt extends _$SetlistDetailSyncedAt {
  @override
  DateTime? build(String bandId, String setlistId) => null;

  void set(DateTime? value) => state = value;
}

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
      ref
          .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
          .set(await cache.readSetlistDetailSyncedAt(bandId, setlistId));
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
    ref
        .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
        .set(DateTime.now());
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
    ref
        .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
        .set(DateTime.now());
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
    ref
        .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
        .set(DateTime.now());
  }
}

/// The band the global Setlists tab's list is currently filtered to; `null`
/// means "all bands". Plain (non-family) provider — its notifier's `state`
/// is set directly by `SetlistsScreen`'s filter dropdown.
///
/// Named `SelectedSetlistBandIdFilter`, not `SelectedBandIdFilter` — the
/// latter is already defined in `tracks_provider.dart`, and
/// `add_setlist_tracks_dialog.dart` imports both provider files. A same-named
/// top-level identifier in both would be a Dart ambiguous-import compile
/// error, so this provider is distinctly named despite being functionally
/// identical to Track's filter (see `04-05-PLAN.md`'s naming-deviation
/// note).
@riverpod
class SelectedSetlistBandIdFilter extends _$SelectedSetlistBandIdFilter {
  @override
  String? build() => null;

  /// Sets the filter (`null` = all bands). A public method instead of the
  /// literal `notifier.state = value` instruction — the latter fails
  /// `flutter analyze` (`invalid_use_of_protected_member`) when called from
  /// outside the notifier itself, per the same pattern established by
  /// `SelectedBandIdFilter.setFilter()` (03-03).
  void setFilter(String? bandId) => state = bandId;
}

/// Cache-first `GET /api/setlist/list` data spanning every band the user
/// belongs to, optionally narrowed by [SelectedSetlistBandIdFilter] (mirrors
/// [UserTracksListData]'s cache-first shape, but non-family — [build]
/// watches [selectedSetlistBandIdFilterProvider] directly, so changing the
/// filter automatically triggers a full rebuild with the new cache
/// key/fetch).
/// D-04: `userSetlists` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp (mirrors [HomepageSyncedAt], see
/// `homepage_provider.dart`). Set on a cache hit (from the pre-existing
/// cached value) and bumped unconditionally on every successful
/// [UserSetlistsListData._fetchAndCache] — never on a failed background
/// refresh, since `_refresh()`'s catch branch never reaches that call.
@riverpod
class UserSetlistsSyncedAt extends _$UserSetlistsSyncedAt {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

@riverpod
class UserSetlistsListData extends _$UserSetlistsListData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method.
  /// [_refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// mutation that landed first (WR-02).
  final int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final bandIdFilter = ref.watch(selectedSetlistBandIdFilterProvider);
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readUserSetlists(bandIdFilter);
    if (cached != null) {
      ref
          .read(userSetlistsSyncedAtProvider.notifier)
          .set(await cache.readUserSetlistsSyncedAt(bandIdFilter));
      unawaited(_refresh(bandIdFilter));
      return cached;
    }
    return _fetchAndCache(bandIdFilter);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(
    String? bandIdFilter,
  ) async {
    final setlists = await ref
        .read(publicApiProvider)
        .listUserSetlists(bandIdFilter: bandIdFilter);
    await ref
        .read(cacheServiceProvider)
        .writeUserSetlists(bandIdFilter, setlists);
    ref.read(userSetlistsSyncedAtProvider.notifier).set(DateTime.now());
    return setlists;
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
    final bandIdFilter = ref.read(selectedSetlistBandIdFilterProvider);
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
