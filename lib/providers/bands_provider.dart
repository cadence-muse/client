import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import '../cache/cache_service.dart';

part 'bands_provider.g.dart';

/// Cache-first `GET /api/band/list` data.
///
/// On [build], cached data (if present) is returned immediately with a
/// background refresh kicked off silently (no loading spinner, no error
/// surfaced if the background refresh fails — mirrors [HomepageData]'s
/// cache-first pattern). With no cache, the network fetch happens inline and
/// any [ApiException] becomes an [AsyncError], which is what drives the
/// "Couldn't load bands" + Retry error state.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
@riverpod
class BandsListData extends _$BandsListData {
  Future<void>? _inFlightRefresh;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBands();
    if (cached != null) {
      unawaited(_refresh());
      return cached;
    }
    return _fetchAndCache();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache() async {
    final bands = await ref.read(publicApiProvider).listBands();
    await ref.read(cacheServiceProvider).writeBands(bands);
    return bands;
  }

  /// Silent background refresh fired from [build] on a cache hit. Never
  /// surfaces an error — a failed background refresh just leaves the
  /// currently-cached data displayed.
  Future<void> _refresh() async {
    try {
      final fresh = await _fetchAndCache();
      state = AsyncData(fresh);
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
    try {
      final fresh = await _fetchAndCache();
      state = AsyncData(fresh);
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
      // Otherwise silently keep the last good data visible.
    }
  }
}
