import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cache_service.g.dart';

/// Backing store for one Hive-cached endpoint's box (e.g. `profileBox`,
/// `homepageBox` — see D-02: one Hive box per endpoint). [_HiveStore] is the
/// real, Hive-backed implementation used at runtime; [_InMemoryStore] is a
/// plain-`Map` test double (see [CacheService.inMemory]) that avoids real
/// file I/O in widget tests. One instance backs exactly one box.
abstract class _KeyValueStore {
  Map<String, dynamic>? get(String key);
  Future<void> put(String key, Map<String, dynamic> value);
  Future<void> clear();
}

class _HiveStore implements _KeyValueStore {
  _HiveStore(this._box);

  final Box<Map> _box;

  @override
  Map<String, dynamic>? get(String key) {
    final raw = _box.get(key);
    return raw == null ? null : _deepConvert(raw) as Map<String, dynamic>;
  }

  /// Recursively normalizes Hive's untyped `Map<dynamic, dynamic>`/
  /// `List<dynamic>` return shapes into `Map<String, dynamic>`/typed-List
  /// shapes at every nesting depth (CR-01). Hive's `BinaryReaderImpl`
  /// (`readMap()`/`readList()`) always constructs `<dynamic, dynamic>`/
  /// `<dynamic>` containers on a real disk read — a shallow top-level-only
  /// conversion leaves nested values (e.g. a band's `members` list) as
  /// untyped containers that throw `TypeError` on the first lazy
  /// `.cast<Map<String, dynamic>>()` access downstream.
  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key as String, _deepConvert(val)),
      );
    }
    if (value is List) {
      return value.map(_deepConvert).toList();
    }
    return value;
  }

  @override
  Future<void> put(String key, Map<String, dynamic> value) =>
      _box.put(key, value);

  @override
  Future<void> clear() => _box.clear();
}

class _InMemoryStore implements _KeyValueStore {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Map<String, dynamic>? get(String key) => _data[key];

  @override
  Future<void> put(String key, Map<String, dynamic> value) async =>
      _data[key] = value;

  @override
  Future<void> clear() async => _data.clear();
}

/// Local read-only cache store, backed by Hive.
///
/// Each box holds the raw decoded JSON `Map<String, dynamic>` response body
/// for one API endpoint — no `TypeAdapter`/typed model classes, reusing the
/// same `fromJson`-free decode path as live network responses (see D-03 in
/// `01-CONTEXT.md`).
///
/// [initialize] does NOT call `Hive.initFlutter()` itself — that stays the
/// caller's job (see `lib/main.dart`).
class CacheService {
  CacheService._(
    this._profileStore,
    this._homepageStore,
    this._bandsStore,
    this._tracksStore,
    this._setlistsStore,
  );

  /// Test double backed by plain in-memory `Map`s, with no Hive/file I/O.
  /// Used via `cacheServiceProvider.overrideWithValue(CacheService.inMemory())`
  /// in widget tests.
  @visibleForTesting
  factory CacheService.inMemory() => CacheService._(
    _InMemoryStore(),
    _InMemoryStore(),
    _InMemoryStore(),
    _InMemoryStore(),
    _InMemoryStore(),
  );

  static CacheService? _instance;

  final _KeyValueStore _profileStore;
  final _KeyValueStore _homepageStore;
  final _KeyValueStore _bandsStore;
  final _KeyValueStore _tracksStore;
  final _KeyValueStore _setlistsStore;

  static Future<void> initialize() async {
    final profileBox = await Hive.openBox<Map>('profileBox');
    final homepageBox = await Hive.openBox<Map>('homepageBox');
    final bandsBox = await Hive.openBox<Map>('bandsBox');
    final tracksBox = await Hive.openBox<Map>('tracksBox');
    final setlistsBox = await Hive.openBox<Map>('setlistsBox');
    _instance = CacheService._(
      _HiveStore(profileBox),
      _HiveStore(homepageBox),
      _HiveStore(bandsBox),
      _HiveStore(tracksBox),
      _HiveStore(setlistsBox),
    );
  }

  static CacheService get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('CacheService.initialize() must be called before use.');
    }
    return instance;
  }

  static const _profileKey = 'profile';
  static const _homepageKey = 'homepage';
  static const _bandsKey = 'bands';

  Future<Map<String, dynamic>?> readProfile() async {
    try {
      final wrapped = _profileStore.get(_profileKey);
      if (wrapped == null) return null;
      return wrapped['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(Map<String, dynamic> data) async {
    try {
      await _profileStore.put(_profileKey, {
        'data': data,
        'syncedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  /// D-04/D-05: independent `syncedAt` for the `profile` cache key, written
  /// atomically alongside `data` in the same [writeProfile] call. `null`
  /// before any write, or on any read exception.
  Future<DateTime?> readProfileSyncedAt() async {
    try {
      final wrapped = _profileStore.get(_profileKey);
      if (wrapped == null) return null;
      return DateTime.parse(wrapped['syncedAt'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readHomepage() async {
    try {
      return _homepageStore.get(_homepageKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeHomepage(Map<String, dynamic> data) async {
    try {
      await _homepageStore.put(_homepageKey, data);
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  Future<List<Map<String, dynamic>>?> readBands() async {
    try {
      final cached = _bandsStore.get(_bandsKey);
      if (cached == null) return null;
      return (cached['items'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBands(List<Map<String, dynamic>> data) async {
    try {
      await _bandsStore.put(_bandsKey, {'items': data});
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  Future<Map<String, dynamic>?> readBandDetail(String bandId) async {
    try {
      return _bandsStore.get(_bandDetailKey(bandId));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBandDetail(String bandId, Map<String, dynamic> data) async {
    try {
      await _bandsStore.put(_bandDetailKey(bandId), data);
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  static String _bandDetailKey(String bandId) => 'band_$bandId';

  Future<List<Map<String, dynamic>>?> readBandTracks(String bandId) async {
    try {
      final cached = _tracksStore.get(_bandTracksKey(bandId));
      if (cached == null) return null;
      return (cached['items'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBandTracks(
    String bandId,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      await _tracksStore.put(_bandTracksKey(bandId), {'items': data});
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  static String _bandTracksKey(String bandId) => 'band_$bandId';

  Future<Map<String, dynamic>?> readBandTrackDetail(
    String bandId,
    String trackId,
  ) async {
    try {
      return _tracksStore.get(_trackDetailKey(bandId, trackId));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBandTrackDetail(
    String bandId,
    String trackId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _tracksStore.put(_trackDetailKey(bandId, trackId), data);
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  static String _trackDetailKey(String bandId, String trackId) =>
      'detail_${bandId}_$trackId';

  Future<List<Map<String, dynamic>>?> readUserTracks(
    String? bandIdFilter,
  ) async {
    try {
      final cached = _tracksStore.get(_userTracksKey(bandIdFilter));
      if (cached == null) return null;
      return (cached['items'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeUserTracks(
    String? bandIdFilter,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      await _tracksStore.put(_userTracksKey(bandIdFilter), {'items': data});
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  static String _userTracksKey(String? bandIdFilter) =>
      'user_tracks_${bandIdFilter ?? 'all'}';

  Future<List<Map<String, dynamic>>?> readBandSetlists(String bandId) async {
    try {
      final cached = _setlistsStore.get(_bandSetlistsKey(bandId));
      if (cached == null) return null;
      return (cached['items'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBandSetlists(
    String bandId,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      await _setlistsStore.put(_bandSetlistsKey(bandId), {'items': data});
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  static String _bandSetlistsKey(String bandId) => 'band_$bandId';

  Future<Map<String, dynamic>?> readSetlistDetail(
    String bandId,
    String setlistId,
  ) async {
    try {
      return _setlistsStore.get(_setlistDetailKey(bandId, setlistId));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSetlistDetail(
    String bandId,
    String setlistId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _setlistsStore.put(_setlistDetailKey(bandId, setlistId), data);
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  static String _setlistDetailKey(String bandId, String setlistId) =>
      'detail_${bandId}_$setlistId';

  Future<List<Map<String, dynamic>>?> readUserSetlists(
    String? bandIdFilter,
  ) async {
    try {
      final cached = _setlistsStore.get(_userSetlistsKey(bandIdFilter));
      if (cached == null) return null;
      return (cached['items'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeUserSetlists(
    String? bandIdFilter,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      await _setlistsStore.put(_userSetlistsKey(bandIdFilter), {
        'items': data,
      });
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  static String _userSetlistsKey(String? bandIdFilter) =>
      'user_setlists_${bandIdFilter ?? 'all'}';

  Future<void> clearAll() async {
    await _profileStore.clear();
    await _homepageStore.clear();
    await _bandsStore.clear();
    await _tracksStore.clear();
    await _setlistsStore.clear();
  }
}

@riverpod
CacheService cacheService(CacheServiceRef ref) => CacheService.instance;
