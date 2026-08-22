import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import 'connectivity_provider.dart';
import 'offline_no_cache_exception.dart';
import '../cache/cache_service.dart';

part 'homepage_provider.g.dart';

/// Online-first `GET /api/homepage` data (D-01/D-03/D-06).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load home" + Retry) when there's nothing
/// cached either. When offline, cached data is served directly with zero
/// network calls, or [OfflineNoCacheException] is thrown if nothing has ever
/// been cached (D-06) — recovery from that state is automatic the moment
/// [isOnlineProvider] flips back to true, since [build] re-watches it. This
/// provider has no `_version` guard (unlike bands/tracks/setlists) — there
/// are no local-mutation methods here to race against.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
@riverpod
class HomepageData extends _$HomepageData {
  Future<void>? _inFlightRefresh;

  @override
  Future<Map<String, dynamic>> build() async {
    final isOnline = ref.watch(isOnlineProvider);
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      try {
        return await _fetchAndCache();
      } catch (_) {
        // D-03: online but the fetch itself failed — fall back to cache
        // silently, the same as a true-offline cache hit.
        final cached = await cache.readHomepage();
        if (cached != null) {
          return cached;
        }
        rethrow;
      }
    }

    final cached = await cache.readHomepage();
    if (cached != null) {
      return cached;
    }
    // D-06: offline with nothing ever cached.
    throw const OfflineNoCacheException();
  }

  Future<Map<String, dynamic>> _fetchAndCache() async {
    final apiClient = ref.read(apiClientProvider);
    final data = await apiClient.send('GET', '/api/homepage');
    final homepage = data!;
    await ref.read(cacheServiceProvider).writeHomepage(homepage);
    return homepage;
  }

  /// User-initiated refresh (e.g. the refresh button). Deduplicates
  /// concurrent calls so tapping refresh twice in quick succession triggers
  /// exactly one network request.
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
