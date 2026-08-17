import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import '../cache/cache_service.dart';

part 'profile_provider.g.dart';

/// Cache-first `GET /api/me` data.
///
/// On [build], cached data (if present) is returned immediately with a
/// background refresh kicked off silently (no loading spinner, no error
/// surfaced if the background refresh fails — D-04/D-06 in
/// `01-CONTEXT.md`). With no cache, the network fetch happens inline and any
/// [ApiException] becomes an [AsyncError], which is what drives the
/// "Couldn't load profile" + Retry error state.
///
/// [refresh] (the UI's pull-to-refresh / refresh-button entry point) dedupes
/// concurrent calls: a second call while one is already in flight reuses the
/// same [Future] rather than firing a second network request.
/// D-05/D-06: `profile` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp. Set on a cache hit (from the
/// pre-existing cached value) and bumped unconditionally on every successful
/// [ProfileData._fetchAndCache] — never on a failed background refresh,
/// since `_refresh()`'s catch branch never reaches that call.
@riverpod
class ProfileSyncedAt extends _$ProfileSyncedAt {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

@riverpod
class ProfileData extends _$ProfileData {
  Future<void>? _inFlightRefresh;

  @override
  Future<Map<String, dynamic>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readProfile();
    if (cached != null) {
      ref
          .read(profileSyncedAtProvider.notifier)
          .set(await cache.readProfileSyncedAt());
      unawaited(_refresh());
      return cached;
    }
    return _fetchAndCache();
  }

  Future<Map<String, dynamic>> _fetchAndCache() async {
    final apiClient = ref.read(apiClientProvider);
    final data = await apiClient.send('GET', '/api/me');
    final profile = data!;
    await ref.read(cacheServiceProvider).writeProfile(profile);
    ref.read(profileSyncedAtProvider.notifier).set(DateTime.now());
    return profile;
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
