import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import 'connectivity_provider.dart';
import 'offline_no_cache_exception.dart';
import '../cache/cache_service.dart';

part 'setlists_provider.g.dart';

/// `bandSetlists` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (mirrors [ProfileSyncedAt], see `profile_provider.dart`).
/// Set on a cache hit (from the pre-existing cached value) and bumped
/// unconditionally on every successful
/// [SetlistListData._fetchAndCache]/[SetlistListData.removeFromList] write.
@riverpod
class SetlistListSyncedAt extends _$SetlistListSyncedAt {
  @override
  DateTime? build(String bandId) => null;

  void set(DateTime? value) => state = value;
}

/// Online-first `GET /api/band/{bandId}/setlist/list` data, keyed per band
/// (D-01/D-03/D-06; family provider — mirrors [BandsListData]'s online-first
/// shape, see `bands_provider.dart`).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Failed to load setlists" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
@riverpod
class SetlistListData extends _$SetlistListData {
  Future<void>? _inFlightRefresh;

  /// Set by [refresh]`(force: true)` when a call arrives while a refresh
  /// is already in flight. Checked by [_runRefresh] right after the
  /// in-flight fetch completes: if set, one more `_doRefresh()` is run
  /// before resolving — otherwise a caller like
  /// `SetlistDetailScreen._removeTrack` that needs a *guaranteed*
  /// post-mutation resync could have its refresh() silently absorbed into
  /// a fetch that started before its mutation landed on the server, and
  /// never see a resync that actually reflects it (WR-01).
  bool _refreshPending = false;

  /// Monotonic counter bumped by every local-mutation method.
  /// [refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// mutation that landed first (WR-02).
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
        final cached = await cache.readBandSetlists(bandId);
        if (cached != null) {
          ref
              .read(setlistListSyncedAtProvider(bandId).notifier)
              .set(await cache.readBandSetlistsSyncedAt(bandId));
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readBandSetlists(bandId);
    if (cached != null) {
      ref
          .read(setlistListSyncedAtProvider(bandId).notifier)
          .set(await cache.readBandSetlistsSyncedAt(bandId));
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final setlists = await ref
        .read(publicApiProvider)
        .listBandSetlists(bandId);
    final wrote = await ref
        .read(cacheServiceProvider)
        .writeBandSetlists(bandId, setlists);
    // WR-02: only claim "just synced" if the cache write actually
    // succeeded.
    if (wrote) {
      ref
          .read(setlistListSyncedAtProvider(bandId).notifier)
          .set(DateTime.now());
    }
    return setlists;
  }

  /// User-initiated refresh (e.g. the refresh button/pull-to-refresh).
  /// Deduplicates concurrent calls so tapping refresh twice in quick
  /// succession triggers exactly one network request.
  ///
  /// [force]: used by mutation call sites that need a *guaranteed*
  /// post-mutation resync (e.g. `SetlistDetailScreen._removeTrack`'s
  /// `.refresh()` after `deleteSetlist`/`removeSetlistTrack`), as opposed
  /// to a plain UI refresh tap. If a refresh is already in flight when a
  /// forced call arrives, that in-flight fetch might have started *before*
  /// this call's mutation reached the server — plain dedup would let the
  /// forced caller's `await` resolve against stale data. `force: true`
  /// instead queues one more `_doRefresh()` run (via [_refreshPending])
  /// after the in-flight fetch completes, so the forced caller's `await`
  /// only resolves once a fetch that started no earlier than its own call
  /// has completed (WR-01). Omitted (`false`) by plain UI refreshes, so
  /// "tap refresh twice quickly" still collapses into exactly one network
  /// call, unchanged.
  Future<void> refresh({bool force = false}) {
    if (_inFlightRefresh != null) {
      if (force) _refreshPending = true;
      return _inFlightRefresh!;
    }
    return _inFlightRefresh = _runRefresh();
  }

  Future<void> _runRefresh() async {
    do {
      _refreshPending = false;
      await _doRefresh();
    } while (_refreshPending);
    _inFlightRefresh = null;
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;
    try {
      final setlists = await ref
          .read(publicApiProvider)
          .listBandSetlists(bandId);
      if (_version != capturedVersion) {
        // A local mutation (e.g. removeFromList) landed while this fetch
        // was in flight — discard the stale response entirely, including
        // the cache write, so it can't silently revert the mutation's
        // on-disk cache (CR-01) even though the in-memory `state` is
        // already correct.
        return;
      }
      final wrote = await ref
          .read(cacheServiceProvider)
          .writeBandSetlists(bandId, setlists);
      if (wrote) {
        ref
            .read(setlistListSyncedAtProvider(bandId).notifier)
            .set(DateTime.now());
      }
      state = AsyncData(setlists);
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
      ref
          .read(cacheServiceProvider)
          .writeBandSetlists(bandId, filtered)
          .then((wrote) {
            // WR-02: only claim "just synced" if the write actually
            // succeeded.
            if (wrote) {
              ref
                  .read(setlistListSyncedAtProvider(bandId).notifier)
                  .set(DateTime.now());
            }
          }),
    );
  }
}

/// Family counterpart of [SetlistListSyncedAt] for
/// `GET /api/band/{bandId}/setlist/{setlistId}`, keyed per `(bandId,
/// setlistId)` pair to match [SetlistDetailData]'s `build(String bandId,
/// String setlistId)` shape.
@riverpod
class SetlistDetailSyncedAt extends _$SetlistDetailSyncedAt {
  @override
  DateTime? build(String bandId, String setlistId) => null;

  void set(DateTime? value) => state = value;
}

/// Online-first `GET /api/band/{bandId}/setlist/{setlistId}` data (D-01/
/// D-03/D-06), keyed per `(bandId, setlistId)` pair (family provider —
/// mirrors [BandDetailData]'s online-first shape, see `bands_provider.dart`).
///
/// Mirrors [SetlistListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not consulted
/// on the happy path); a failed online fetch falls back to cache silently
/// (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `SetlistDetailScreen`.
@riverpod
class SetlistDetailData extends _$SetlistDetailData {
  Future<void>? _inFlightRefresh;

  /// Set by [refresh]`(force: true)` when a call arrives while a refresh
  /// is already in flight. Checked by [_runRefresh] right after the
  /// in-flight fetch completes: if set, one more `_doRefresh()` is run
  /// before resolving — otherwise `SetlistDetailScreen._removeTrack`
  /// removing two *different* tracks in quick succession could have the
  /// second removal's post-mutate resync silently absorbed into a fetch
  /// that started before that removal reached the server, leaving the
  /// removed track visible until an unrelated manual refresh (WR-01).
  bool _refreshPending = false;

  /// Monotonic counter bumped by every local-mutation method.
  /// [refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// edit that landed first (WR-02).
  int _version = 0;

  @override
  Future<Map<String, dynamic>> build(String bandId, String setlistId) async {
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      try {
        return await _fetchAndCache(bandId, setlistId);
      } catch (_) {
        // D-03: online but the fetch itself failed — fall back to cache
        // silently, the same as a true-offline cache hit.
        final cached = await cache.readSetlistDetail(bandId, setlistId);
        if (cached != null) {
          ref
              .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
              .set(await cache.readSetlistDetailSyncedAt(bandId, setlistId));
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readSetlistDetail(bandId, setlistId);
    if (cached != null) {
      ref
          .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
          .set(await cache.readSetlistDetailSyncedAt(bandId, setlistId));
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
  }

  Future<Map<String, dynamic>> _fetchAndCache(
    String bandId,
    String setlistId,
  ) async {
    final setlist = await ref
        .read(publicApiProvider)
        .getSetlist(bandId, setlistId);
    final wrote = await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, setlist);
    // WR-02: only claim "just synced" if the cache write actually
    // succeeded.
    if (wrote) {
      ref
          .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
          .set(DateTime.now());
    }
    return setlist;
  }

  /// User-initiated refresh (e.g. the refresh button/pull-to-refresh).
  /// Deduplicates concurrent calls so tapping refresh twice in quick
  /// succession triggers exactly one network request.
  ///
  /// [force]: used by mutation call sites that need a *guaranteed*
  /// post-mutation resync (e.g. `SetlistDetailScreen._removeTrack`'s
  /// `.refresh()` after `removeSetlistTrack`), as opposed to a plain UI
  /// refresh tap. If a refresh is already in flight when a forced call
  /// arrives, that in-flight fetch might have started *before* this call's
  /// mutation reached the server — plain dedup would let the forced
  /// caller's `await` resolve against stale data (WR-01, reproduced by
  /// removing two different tracks in quick succession). `force: true`
  /// instead queues one more `_doRefresh()` run (via [_refreshPending])
  /// after the in-flight fetch completes, so the forced caller's `await`
  /// only resolves once a fetch that started no earlier than its own call
  /// has completed. Omitted (`false`) by plain UI refreshes, so "tap
  /// refresh twice quickly" still collapses into exactly one network call,
  /// unchanged.
  Future<void> refresh({bool force = false}) {
    if (_inFlightRefresh != null) {
      if (force) _refreshPending = true;
      return _inFlightRefresh!;
    }
    return _inFlightRefresh = _runRefresh();
  }

  Future<void> _runRefresh() async {
    do {
      _refreshPending = false;
      await _doRefresh();
    } while (_refreshPending);
    _inFlightRefresh = null;
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;
    try {
      final setlist = await ref
          .read(publicApiProvider)
          .getSetlist(bandId, setlistId);
      if (_version != capturedVersion) {
        // A local mutation (e.g. updateFields/reorderTracks) landed while
        // this fetch was in flight — discard the stale response entirely,
        // including the cache write, so it can't silently revert the
        // mutation's on-disk cache (CR-01) even though the in-memory
        // `state` is already correct.
        return;
      }
      final wrote = await ref
          .read(cacheServiceProvider)
          .writeSetlistDetail(bandId, setlistId, setlist);
      if (wrote) {
        ref
            .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
            .set(DateTime.now());
      }
      state = AsyncData(setlist);
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
    final wrote = await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, updated);
    // WR-02: only claim "just synced" if the cache write actually
    // succeeded.
    if (wrote) {
      ref
          .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
          .set(DateTime.now());
    }
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
    final wrote = await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, updated);
    // WR-02: only claim "just synced" if the cache write actually
    // succeeded.
    if (wrote) {
      ref
          .read(setlistDetailSyncedAtProvider(bandId, setlistId).notifier)
          .set(DateTime.now());
    }
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

/// `userSetlists` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (mirrors [HomepageSyncedAt], see
/// `homepage_provider.dart`). Set on a cache hit (from the pre-existing
/// cached value) and bumped unconditionally on every successful
/// [UserSetlistsListData._fetchAndCache] write.
@riverpod
class UserSetlistsSyncedAt extends _$UserSetlistsSyncedAt {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

/// Online-first `GET /api/setlist/list` data spanning every band the user
/// belongs to, optionally narrowed by [SelectedSetlistBandIdFilter] (D-01/
/// D-03/D-06; mirrors [UserTracksListData]'s online-first shape, but
/// non-family — [build] watches [selectedSetlistBandIdFilterProvider]
/// directly, so changing the filter automatically triggers a full rebuild
/// with the new cache key/fetch).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError]) when there's nothing cached either. When offline, cached
/// data is served directly with zero network calls, or
/// [OfflineNoCacheException] is thrown if nothing has ever been cached
/// (D-06) — recovery from that state is automatic the moment
/// [isOnlineProvider] flips back to true, since [build] re-watches it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
@riverpod
class UserSetlistsListData extends _$UserSetlistsListData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method.
  /// [refresh]/[_doRefresh] capture this before their network await and
  /// discard a fetched result if it changed while the fetch was in flight —
  /// otherwise a slower background refresh could silently revert a local
  /// mutation that landed first (WR-02). Never bumped in practice (this
  /// provider has no local-mutation methods), but kept for shape parity
  /// with [UserTracksListData]/[SetlistListData]/[SetlistDetailData].
  final int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final bandIdFilter = ref.watch(selectedSetlistBandIdFilterProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      try {
        return await _fetchAndCache(bandIdFilter);
      } catch (_) {
        // D-03: online but the fetch itself failed — fall back to cache
        // silently, the same as a true-offline cache hit.
        final cached = await cache.readUserSetlists(bandIdFilter);
        if (cached != null) {
          ref
              .read(userSetlistsSyncedAtProvider.notifier)
              .set(await cache.readUserSetlistsSyncedAt(bandIdFilter));
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readUserSetlists(bandIdFilter);
    if (cached != null) {
      ref
          .read(userSetlistsSyncedAtProvider.notifier)
          .set(await cache.readUserSetlistsSyncedAt(bandIdFilter));
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(
    String? bandIdFilter,
  ) async {
    final setlists = await ref
        .read(publicApiProvider)
        .listUserSetlists(bandIdFilter: bandIdFilter);
    final wrote = await ref
        .read(cacheServiceProvider)
        .writeUserSetlists(bandIdFilter, setlists);
    // WR-02: only claim "just synced" if the cache write actually
    // succeeded.
    if (wrote) {
      ref.read(userSetlistsSyncedAtProvider.notifier).set(DateTime.now());
    }
    return setlists;
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
