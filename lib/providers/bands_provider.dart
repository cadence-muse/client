import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import 'connectivity_provider.dart';
import 'offline_no_cache_exception.dart';
import '../cache/cache_service.dart';

part 'bands_provider.g.dart';

/// D-04/D-05 (05-01-PLAN.md): independent `syncedAt` for the `bands` list
/// cache key, mirroring [ProfileSyncedAt]'s shape. Set from the cache's
/// stored timestamp on a cache hit, and bumped unconditionally on every
/// successful cache write (fetch or local mutation) — never gated by
/// [BandsListData]'s `_version` guard, since the cache write it mirrors
/// already succeeded regardless of whether the fetched data itself gets
/// discarded (05-RESEARCH.md Pitfall 6).
@riverpod
class BandsListSyncedAt extends _$BandsListSyncedAt {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

/// Family counterpart of [BandsListSyncedAt] for `GET /api/band/{bandId}`,
/// keyed per band to match [BandDetailData]'s `build(String bandId)` shape.
@riverpod
class BandDetailSyncedAt extends _$BandDetailSyncedAt {
  @override
  DateTime? build(String bandId) => null;

  void set(DateTime? value) => state = value;
}

/// Online-first `GET /api/band/list` data (D-01/D-03/D-06).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load bands" + Retry) when there's nothing
/// cached either. When offline, cached data is served directly with zero
/// network calls, or [OfflineNoCacheException] is thrown if nothing has ever
/// been cached (D-06) — recovery from that state is automatic the moment
/// [isOnlineProvider] flips back to true, since [build] re-watches it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
@riverpod
class BandsListData extends _$BandsListData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method ([setBands],
  /// [renameBand]). [refresh]/[_doRefresh] capture this before their
  /// network await and discard a fetched result if it changed while the
  /// fetch was in flight — otherwise a slower background refresh could
  /// silently revert a local edit that landed first (WR-02).
  int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      try {
        return await _fetchAndCache();
      } catch (_) {
        // D-03: online but the fetch itself failed — fall back to cache
        // silently, the same as a true-offline cache hit.
        final cached = await cache.readBands();
        if (cached != null) {
          ref
              .read(bandsListSyncedAtProvider.notifier)
              .set(await cache.readBandsSyncedAt());
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readBands();
    if (cached != null) {
      ref
          .read(bandsListSyncedAtProvider.notifier)
          .set(await cache.readBandsSyncedAt());
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache() async {
    final bands = await ref.read(publicApiProvider).listBands();
    await ref.read(cacheServiceProvider).writeBands(bands);
    ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
    return bands;
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
      final fresh = await _fetchAndCache();
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

  /// Overwrites the cached list with data already fetched by the caller
  /// (e.g. [showJoinBandDialog]'s post-join `listBands()` call), without
  /// firing another network request.
  void setBands(List<Map<String, dynamic>> bands) {
    _version++;
    state = AsyncData(bands);
    ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
  }

  /// Patches [bandId]'s name in-place in the cached list after a
  /// successful `updateBand()` call (WR-01 gap-closure), mirroring
  /// [setBands]'s direct-state-patch pattern so BandsScreen (kept alive in
  /// RootScaffold's IndexedStack) reflects a rename immediately instead of
  /// showing the old name until an unrelated manual refresh.
  void renameBand(String bandId, String newName) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = [
      for (final band in current)
        if (band['id'] == bandId) {...band, 'name': newName} else band,
    ];
    _version++;
    state = AsyncData(updated);
    unawaited(ref.read(cacheServiceProvider).writeBands(updated));
    ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
  }

  /// Patches [bandId]'s `ownerId` in-place in the cached list after a
  /// successful `transferOwnership()` call (D-10), using the known target
  /// [newOwnerId] — `TransferBandOwnership`'s `'200'` response has no body
  /// to trust, but the transfer already succeeded server-side by the time
  /// this is called, so patching the list optimistically here is safe even
  /// though the detail-side change (D-09) separately triggers a refetch.
  /// Mirrors [renameBand]'s exact shape. No-ops if there's no data to patch
  /// into.
  void patchBandOwner(String bandId, String newOwnerId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = [
      for (final band in current)
        if (band['id'] == bandId)
          {...band, 'ownerId': newOwnerId}
        else
          band,
    ];
    _version++;
    state = AsyncData(updated);
    unawaited(ref.read(cacheServiceProvider).writeBands(updated));
    ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
  }
}

/// Online-first `GET /api/band/{bandId}` data (D-01/D-03/D-06), keyed per
/// band (this project's first family provider — [build]'s extra `bandId`
/// parameter is auto-detected by riverpod_generator as the family key).
///
/// Mirrors [BandsListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not
/// consulted on the happy path); a failed online fetch falls back to cache
/// silently (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `BandDetailScreen`.
@riverpod
class BandDetailData extends _$BandDetailData {
  Future<void>? _inFlightRefresh;

  /// Monotonic counter bumped by every local-mutation method
  /// ([updateName]). [refresh]/[_doRefresh] capture this before their
  /// network await and discard a fetched result if it changed while the
  /// fetch was in flight — otherwise a slower background refresh could
  /// silently revert a local edit that landed first (WR-02).
  int _version = 0;

  @override
  Future<Map<String, dynamic>> build(String bandId) async {
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      try {
        return await _fetchAndCache(bandId);
      } catch (_) {
        // D-03: online but the fetch itself failed — fall back to cache
        // silently, the same as a true-offline cache hit.
        final cached = await cache.readBandDetail(bandId);
        if (cached != null) {
          ref
              .read(bandDetailSyncedAtProvider(bandId).notifier)
              .set(await cache.readBandDetailSyncedAt(bandId));
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readBandDetail(bandId);
    if (cached != null) {
      ref
          .read(bandDetailSyncedAtProvider(bandId).notifier)
          .set(await cache.readBandDetailSyncedAt(bandId));
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
  }

  Future<Map<String, dynamic>> _fetchAndCache(String bandId) async {
    final band = await ref.read(publicApiProvider).getBand(bandId);
    await ref.read(cacheServiceProvider).writeBandDetail(bandId, band);
    ref.read(bandDetailSyncedAtProvider(bandId).notifier).set(DateTime.now());
    return band;
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

  /// Merges [newName] into the currently cached band-detail map after a
  /// successful [PublicApi.updateBand] call, without an additional network
  /// fetch (`UpdateBand`'s `'200'` response has no body to refetch-and-trust
  /// — see `edit_band_screen.dart`). No-ops if there's no data to merge
  /// into (e.g. called while still loading or in an error state).
  Future<void> updateName(String newName) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = {...current, 'name': newName};
    _version++;
    state = AsyncData(updated);
    await ref.read(cacheServiceProvider).writeBandDetail(bandId, updated);
    ref.read(bandDetailSyncedAtProvider(bandId).notifier).set(DateTime.now());
  }

  /// Merges [newCode] into the currently cached band-detail map after a
  /// successful [PublicApi.rotateInviteCode] call, without an additional
  /// network fetch (D-08 — `RotateBandInviteCode`'s `'200'` response returns
  /// the new code directly, so the server's returned value is trusted and
  /// patched in place rather than triggering a refetch). No-ops if there's
  /// no data to merge into (e.g. called while still loading or in an error
  /// state), mirroring [updateName]'s guard.
  Future<void> rotateInviteCode(String newCode) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = {...current, 'inviteCode': newCode};
    _version++;
    state = AsyncData(updated);
    await ref.read(cacheServiceProvider).writeBandDetail(bandId, updated);
    ref.read(bandDetailSyncedAtProvider(bandId).notifier).set(DateTime.now());
  }
}
