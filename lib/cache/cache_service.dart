import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cache_service.g.dart';

/// Backing store for one Hive-cached endpoint's data. [_HiveProfileStore] is
/// the real, Hive-backed implementation used at runtime; [_InMemoryProfileStore]
/// is a plain-`Map` test double (see [CacheService.inMemory]) that avoids
/// real file I/O in widget tests.
abstract class _ProfileStore {
  Map<String, dynamic>? get(String key);
  Future<void> put(String key, Map<String, dynamic> value);
  Future<void> clear();
}

class _HiveProfileStore implements _ProfileStore {
  _HiveProfileStore(this._box);

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

class _InMemoryProfileStore implements _ProfileStore {
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
  CacheService._(this._store);

  /// Test double backed by a plain in-memory `Map`, with no Hive/file I/O.
  /// Used via `cacheServiceProvider.overrideWithValue(CacheService.inMemory())`
  /// in widget tests.
  @visibleForTesting
  factory CacheService.inMemory() => CacheService._(_InMemoryProfileStore());

  static CacheService? _instance;

  final _ProfileStore _store;

  static Future<void> initialize() async {
    final profileBox = await Hive.openBox<Map>('profileBox');
    _instance = CacheService._(_HiveProfileStore(profileBox));
  }

  static CacheService get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('CacheService.initialize() must be called before use.');
    }
    return instance;
  }

  static const _profileKey = 'profile';

  Future<Map<String, dynamic>?> readProfile() async {
    try {
      return _store.get(_profileKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(Map<String, dynamic> data) async {
    try {
      await _store.put(_profileKey, data);
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  Future<void> clearAll() async {
    await _store.clear();
  }
}

@riverpod
CacheService cacheService(CacheServiceRef ref) => CacheService.instance;
