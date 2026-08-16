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
      unawaited(_refresh(bandId));
      return cached;
    }
    return _fetchAndCache(bandId);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final tracks = await ref.read(publicApiProvider).listBandTracks(bandId);
    await ref.read(cacheServiceProvider).writeBandTracks(bandId, tracks);
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
}

/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
/// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
/// cache-first shape, see `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// tracks" + Retry error state).
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
}
