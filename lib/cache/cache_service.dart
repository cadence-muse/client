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
    return raw == null ? null : Map<String, dynamic>.from(raw);
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
  CacheService._(this._profileStore, this._homepageStore);

  /// Test double backed by plain in-memory `Map`s, with no Hive/file I/O.
  /// Used via `cacheServiceProvider.overrideWithValue(CacheService.inMemory())`
  /// in widget tests.
  @visibleForTesting
  factory CacheService.inMemory() =>
      CacheService._(_InMemoryStore(), _InMemoryStore());

  static CacheService? _instance;

  final _KeyValueStore _profileStore;
  final _KeyValueStore _homepageStore;

  static Future<void> initialize() async {
    final profileBox = await Hive.openBox<Map>('profileBox');
    final homepageBox = await Hive.openBox<Map>('homepageBox');
    _instance = CacheService._(
      _HiveStore(profileBox),
      _HiveStore(homepageBox),
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

  Future<Map<String, dynamic>?> readProfile() async {
    try {
      return _profileStore.get(_profileKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(Map<String, dynamic> data) async {
    try {
      await _profileStore.put(_profileKey, data);
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
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

  Future<void> clearAll() async {
    await _profileStore.clear();
    await _homepageStore.clear();
  }
}

@riverpod
CacheService cacheService(CacheServiceRef ref) => CacheService.instance;
