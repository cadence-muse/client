// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bands_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bandsListSyncedAtHash() => r'c8942315bec411df62f17995166e528c1932ca01';

/// D-04/D-05 (05-01-PLAN.md): independent `syncedAt` for the `bands` list
/// cache key, mirroring [ProfileSyncedAt]'s shape. Set from the cache's
/// stored timestamp on a cache hit, and bumped unconditionally on every
/// successful cache write (fetch or local mutation) — never gated by
/// [BandsListData]'s `_version` guard, since the cache write it mirrors
/// already succeeded regardless of whether the fetched data itself gets
/// discarded (05-RESEARCH.md Pitfall 6).
///
/// Copied from [BandsListSyncedAt].
@ProviderFor(BandsListSyncedAt)
final bandsListSyncedAtProvider =
    AutoDisposeNotifierProvider<BandsListSyncedAt, DateTime?>.internal(
      BandsListSyncedAt.new,
      name: r'bandsListSyncedAtProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bandsListSyncedAtHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BandsListSyncedAt = AutoDisposeNotifier<DateTime?>;
String _$bandDetailSyncedAtHash() =>
    r'128544ff73b52f522a1f47afc3cea51b6866c101';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$BandDetailSyncedAt
    extends BuildlessAutoDisposeNotifier<DateTime?> {
  late final String bandId;

  DateTime? build(String bandId);
}

/// Family counterpart of [BandsListSyncedAt] for `GET /api/band/{bandId}`,
/// keyed per band to match [BandDetailData]'s `build(String bandId)` shape.
///
/// Copied from [BandDetailSyncedAt].
@ProviderFor(BandDetailSyncedAt)
const bandDetailSyncedAtProvider = BandDetailSyncedAtFamily();

/// Family counterpart of [BandsListSyncedAt] for `GET /api/band/{bandId}`,
/// keyed per band to match [BandDetailData]'s `build(String bandId)` shape.
///
/// Copied from [BandDetailSyncedAt].
class BandDetailSyncedAtFamily extends Family<DateTime?> {
  /// Family counterpart of [BandsListSyncedAt] for `GET /api/band/{bandId}`,
  /// keyed per band to match [BandDetailData]'s `build(String bandId)` shape.
  ///
  /// Copied from [BandDetailSyncedAt].
  const BandDetailSyncedAtFamily();

  /// Family counterpart of [BandsListSyncedAt] for `GET /api/band/{bandId}`,
  /// keyed per band to match [BandDetailData]'s `build(String bandId)` shape.
  ///
  /// Copied from [BandDetailSyncedAt].
  BandDetailSyncedAtProvider call(String bandId) {
    return BandDetailSyncedAtProvider(bandId);
  }

  @override
  BandDetailSyncedAtProvider getProviderOverride(
    covariant BandDetailSyncedAtProvider provider,
  ) {
    return call(provider.bandId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'bandDetailSyncedAtProvider';
}

/// Family counterpart of [BandsListSyncedAt] for `GET /api/band/{bandId}`,
/// keyed per band to match [BandDetailData]'s `build(String bandId)` shape.
///
/// Copied from [BandDetailSyncedAt].
class BandDetailSyncedAtProvider
    extends AutoDisposeNotifierProviderImpl<BandDetailSyncedAt, DateTime?> {
  /// Family counterpart of [BandsListSyncedAt] for `GET /api/band/{bandId}`,
  /// keyed per band to match [BandDetailData]'s `build(String bandId)` shape.
  ///
  /// Copied from [BandDetailSyncedAt].
  BandDetailSyncedAtProvider(String bandId)
    : this._internal(
        () => BandDetailSyncedAt()..bandId = bandId,
        from: bandDetailSyncedAtProvider,
        name: r'bandDetailSyncedAtProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$bandDetailSyncedAtHash,
        dependencies: BandDetailSyncedAtFamily._dependencies,
        allTransitiveDependencies:
            BandDetailSyncedAtFamily._allTransitiveDependencies,
        bandId: bandId,
      );

  BandDetailSyncedAtProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bandId,
  }) : super.internal();

  final String bandId;

  @override
  DateTime? runNotifierBuild(covariant BandDetailSyncedAt notifier) {
    return notifier.build(bandId);
  }

  @override
  Override overrideWith(BandDetailSyncedAt Function() create) {
    return ProviderOverride(
      origin: this,
      override: BandDetailSyncedAtProvider._internal(
        () => create()..bandId = bandId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bandId: bandId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<BandDetailSyncedAt, DateTime?>
  createElement() {
    return _BandDetailSyncedAtProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BandDetailSyncedAtProvider && other.bandId == bandId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bandId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BandDetailSyncedAtRef on AutoDisposeNotifierProviderRef<DateTime?> {
  /// The parameter `bandId` of this provider.
  String get bandId;
}

class _BandDetailSyncedAtProviderElement
    extends AutoDisposeNotifierProviderElement<BandDetailSyncedAt, DateTime?>
    with BandDetailSyncedAtRef {
  _BandDetailSyncedAtProviderElement(super.provider);

  @override
  String get bandId => (origin as BandDetailSyncedAtProvider).bandId;
}

String _$bandsListDataHash() => r'562ffd75e0e84b3a33a26aa5f189ee804263db8d';

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
///
/// Copied from [BandsListData].
@ProviderFor(BandsListData)
final bandsListDataProvider =
    AutoDisposeAsyncNotifierProvider<
      BandsListData,
      List<Map<String, dynamic>>
    >.internal(
      BandsListData.new,
      name: r'bandsListDataProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bandsListDataHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BandsListData = AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
String _$bandDetailDataHash() => r'a552d82baf3205c16296e5689af2be5c3ab9cb4a';

abstract class _$BandDetailData
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final String bandId;

  FutureOr<Map<String, dynamic>> build(String bandId);
}

/// Cache-first `GET /api/band/{bandId}` data, keyed per band (this project's
/// first family provider — [build]'s extra `bandId` parameter is
/// auto-detected by riverpod_generator as the family key).
///
/// Mirrors [BandsListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// band details" + Retry error state).
///
/// Copied from [BandDetailData].
@ProviderFor(BandDetailData)
const bandDetailDataProvider = BandDetailDataFamily();

/// Cache-first `GET /api/band/{bandId}` data, keyed per band (this project's
/// first family provider — [build]'s extra `bandId` parameter is
/// auto-detected by riverpod_generator as the family key).
///
/// Mirrors [BandsListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// band details" + Retry error state).
///
/// Copied from [BandDetailData].
class BandDetailDataFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// Cache-first `GET /api/band/{bandId}` data, keyed per band (this project's
  /// first family provider — [build]'s extra `bandId` parameter is
  /// auto-detected by riverpod_generator as the family key).
  ///
  /// Mirrors [BandsListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// band details" + Retry error state).
  ///
  /// Copied from [BandDetailData].
  const BandDetailDataFamily();

  /// Cache-first `GET /api/band/{bandId}` data, keyed per band (this project's
  /// first family provider — [build]'s extra `bandId` parameter is
  /// auto-detected by riverpod_generator as the family key).
  ///
  /// Mirrors [BandsListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// band details" + Retry error state).
  ///
  /// Copied from [BandDetailData].
  BandDetailDataProvider call(String bandId) {
    return BandDetailDataProvider(bandId);
  }

  @override
  BandDetailDataProvider getProviderOverride(
    covariant BandDetailDataProvider provider,
  ) {
    return call(provider.bandId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'bandDetailDataProvider';
}

/// Cache-first `GET /api/band/{bandId}` data, keyed per band (this project's
/// first family provider — [build]'s extra `bandId` parameter is
/// auto-detected by riverpod_generator as the family key).
///
/// Mirrors [BandsListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// band details" + Retry error state).
///
/// Copied from [BandDetailData].
class BandDetailDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          BandDetailData,
          Map<String, dynamic>
        > {
  /// Cache-first `GET /api/band/{bandId}` data, keyed per band (this project's
  /// first family provider — [build]'s extra `bandId` parameter is
  /// auto-detected by riverpod_generator as the family key).
  ///
  /// Mirrors [BandsListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// band details" + Retry error state).
  ///
  /// Copied from [BandDetailData].
  BandDetailDataProvider(String bandId)
    : this._internal(
        () => BandDetailData()..bandId = bandId,
        from: bandDetailDataProvider,
        name: r'bandDetailDataProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$bandDetailDataHash,
        dependencies: BandDetailDataFamily._dependencies,
        allTransitiveDependencies:
            BandDetailDataFamily._allTransitiveDependencies,
        bandId: bandId,
      );

  BandDetailDataProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bandId,
  }) : super.internal();

  final String bandId;

  @override
  FutureOr<Map<String, dynamic>> runNotifierBuild(
    covariant BandDetailData notifier,
  ) {
    return notifier.build(bandId);
  }

  @override
  Override overrideWith(BandDetailData Function() create) {
    return ProviderOverride(
      origin: this,
      override: BandDetailDataProvider._internal(
        () => create()..bandId = bandId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bandId: bandId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<BandDetailData, Map<String, dynamic>>
  createElement() {
    return _BandDetailDataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BandDetailDataProvider && other.bandId == bandId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bandId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BandDetailDataRef
    on AutoDisposeAsyncNotifierProviderRef<Map<String, dynamic>> {
  /// The parameter `bandId` of this provider.
  String get bandId;
}

class _BandDetailDataProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          BandDetailData,
          Map<String, dynamic>
        >
    with BandDetailDataRef {
  _BandDetailDataProviderElement(super.provider);

  @override
  String get bandId => (origin as BandDetailDataProvider).bandId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
