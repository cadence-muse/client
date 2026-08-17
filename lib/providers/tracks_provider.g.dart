// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$trackListSyncedAtHash() => r'f2ae10e193362aeb4d6e2f4e2e1f4f94cc04f811';

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

abstract class _$TrackListSyncedAt
    extends BuildlessAutoDisposeNotifier<DateTime?> {
  late final String bandId;

  DateTime? build(String bandId);
}

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
/// `bandTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (family, keyed per band — mirrors [ProfileSyncedAt]'s
/// shape, see `profile_provider.dart`). Set on a cache hit (from the
/// pre-existing cached value) and bumped unconditionally on every successful
/// [TrackListData._fetchAndCache]/[TrackListData.removeFromList] — never on
/// a failed background refresh, since `_refresh()`'s catch branch never
/// reaches that call.
///
/// Copied from [TrackListSyncedAt].
@ProviderFor(TrackListSyncedAt)
const trackListSyncedAtProvider = TrackListSyncedAtFamily();

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
/// `bandTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (family, keyed per band — mirrors [ProfileSyncedAt]'s
/// shape, see `profile_provider.dart`). Set on a cache hit (from the
/// pre-existing cached value) and bumped unconditionally on every successful
/// [TrackListData._fetchAndCache]/[TrackListData.removeFromList] — never on
/// a failed background refresh, since `_refresh()`'s catch branch never
/// reaches that call.
///
/// Copied from [TrackListSyncedAt].
class TrackListSyncedAtFamily extends Family<DateTime?> {
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
  /// `bandTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
  /// stored timestamp (family, keyed per band — mirrors [ProfileSyncedAt]'s
  /// shape, see `profile_provider.dart`). Set on a cache hit (from the
  /// pre-existing cached value) and bumped unconditionally on every successful
  /// [TrackListData._fetchAndCache]/[TrackListData.removeFromList] — never on
  /// a failed background refresh, since `_refresh()`'s catch branch never
  /// reaches that call.
  ///
  /// Copied from [TrackListSyncedAt].
  const TrackListSyncedAtFamily();

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
  /// `bandTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
  /// stored timestamp (family, keyed per band — mirrors [ProfileSyncedAt]'s
  /// shape, see `profile_provider.dart`). Set on a cache hit (from the
  /// pre-existing cached value) and bumped unconditionally on every successful
  /// [TrackListData._fetchAndCache]/[TrackListData.removeFromList] — never on
  /// a failed background refresh, since `_refresh()`'s catch branch never
  /// reaches that call.
  ///
  /// Copied from [TrackListSyncedAt].
  TrackListSyncedAtProvider call(String bandId) {
    return TrackListSyncedAtProvider(bandId);
  }

  @override
  TrackListSyncedAtProvider getProviderOverride(
    covariant TrackListSyncedAtProvider provider,
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
  String? get name => r'trackListSyncedAtProvider';
}

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
/// `bandTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (family, keyed per band — mirrors [ProfileSyncedAt]'s
/// shape, see `profile_provider.dart`). Set on a cache hit (from the
/// pre-existing cached value) and bumped unconditionally on every successful
/// [TrackListData._fetchAndCache]/[TrackListData.removeFromList] — never on
/// a failed background refresh, since `_refresh()`'s catch branch never
/// reaches that call.
///
/// Copied from [TrackListSyncedAt].
class TrackListSyncedAtProvider
    extends AutoDisposeNotifierProviderImpl<TrackListSyncedAt, DateTime?> {
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
  /// `bandTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
  /// stored timestamp (family, keyed per band — mirrors [ProfileSyncedAt]'s
  /// shape, see `profile_provider.dart`). Set on a cache hit (from the
  /// pre-existing cached value) and bumped unconditionally on every successful
  /// [TrackListData._fetchAndCache]/[TrackListData.removeFromList] — never on
  /// a failed background refresh, since `_refresh()`'s catch branch never
  /// reaches that call.
  ///
  /// Copied from [TrackListSyncedAt].
  TrackListSyncedAtProvider(String bandId)
    : this._internal(
        () => TrackListSyncedAt()..bandId = bandId,
        from: trackListSyncedAtProvider,
        name: r'trackListSyncedAtProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$trackListSyncedAtHash,
        dependencies: TrackListSyncedAtFamily._dependencies,
        allTransitiveDependencies:
            TrackListSyncedAtFamily._allTransitiveDependencies,
        bandId: bandId,
      );

  TrackListSyncedAtProvider._internal(
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
  DateTime? runNotifierBuild(covariant TrackListSyncedAt notifier) {
    return notifier.build(bandId);
  }

  @override
  Override overrideWith(TrackListSyncedAt Function() create) {
    return ProviderOverride(
      origin: this,
      override: TrackListSyncedAtProvider._internal(
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
  AutoDisposeNotifierProviderElement<TrackListSyncedAt, DateTime?>
  createElement() {
    return _TrackListSyncedAtProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackListSyncedAtProvider && other.bandId == bandId;
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
mixin TrackListSyncedAtRef on AutoDisposeNotifierProviderRef<DateTime?> {
  /// The parameter `bandId` of this provider.
  String get bandId;
}

class _TrackListSyncedAtProviderElement
    extends AutoDisposeNotifierProviderElement<TrackListSyncedAt, DateTime?>
    with TrackListSyncedAtRef {
  _TrackListSyncedAtProviderElement(super.provider);

  @override
  String get bandId => (origin as TrackListSyncedAtProvider).bandId;
}

String _$trackListDataHash() => r'e1786ad24aa5e63d29430a3aaeee08da1f283382';

abstract class _$TrackListData
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final String bandId;

  FutureOr<List<Map<String, dynamic>>> build(String bandId);
}

/// See also [TrackListData].
@ProviderFor(TrackListData)
const trackListDataProvider = TrackListDataFamily();

/// See also [TrackListData].
class TrackListDataFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// See also [TrackListData].
  const TrackListDataFamily();

  /// See also [TrackListData].
  TrackListDataProvider call(String bandId) {
    return TrackListDataProvider(bandId);
  }

  @override
  TrackListDataProvider getProviderOverride(
    covariant TrackListDataProvider provider,
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
  String? get name => r'trackListDataProvider';
}

/// See also [TrackListData].
class TrackListDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          TrackListData,
          List<Map<String, dynamic>>
        > {
  /// See also [TrackListData].
  TrackListDataProvider(String bandId)
    : this._internal(
        () => TrackListData()..bandId = bandId,
        from: trackListDataProvider,
        name: r'trackListDataProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$trackListDataHash,
        dependencies: TrackListDataFamily._dependencies,
        allTransitiveDependencies:
            TrackListDataFamily._allTransitiveDependencies,
        bandId: bandId,
      );

  TrackListDataProvider._internal(
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
  FutureOr<List<Map<String, dynamic>>> runNotifierBuild(
    covariant TrackListData notifier,
  ) {
    return notifier.build(bandId);
  }

  @override
  Override overrideWith(TrackListData Function() create) {
    return ProviderOverride(
      origin: this,
      override: TrackListDataProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<
    TrackListData,
    List<Map<String, dynamic>>
  >
  createElement() {
    return _TrackListDataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackListDataProvider && other.bandId == bandId;
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
mixin TrackListDataRef
    on AutoDisposeAsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `bandId` of this provider.
  String get bandId;
}

class _TrackListDataProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          TrackListData,
          List<Map<String, dynamic>>
        >
    with TrackListDataRef {
  _TrackListDataProviderElement(super.provider);

  @override
  String get bandId => (origin as TrackListDataProvider).bandId;
}

String _$trackDetailSyncedAtHash() =>
    r'93fddbb74bbea9ea437f848017dcb9ac8e5ad316';

abstract class _$TrackDetailSyncedAt
    extends BuildlessAutoDisposeNotifier<DateTime?> {
  late final String bandId;
  late final String trackId;

  DateTime? build(String bandId, String trackId);
}

/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
/// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
/// cache-first shape, see `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// tracks" + Retry error state).
/// `bandTrackDetail` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp (family, keyed per `(bandId,
/// trackId)` pair). Set on a cache hit (from the pre-existing cached value)
/// and bumped unconditionally on every successful
/// [TrackDetailData._fetchAndCache]/[TrackDetailData.updateFields] — never
/// on a failed background refresh, since `_refresh()`'s catch branch never
/// reaches that call.
///
/// Copied from [TrackDetailSyncedAt].
@ProviderFor(TrackDetailSyncedAt)
const trackDetailSyncedAtProvider = TrackDetailSyncedAtFamily();

/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
/// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
/// cache-first shape, see `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// tracks" + Retry error state).
/// `bandTrackDetail` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp (family, keyed per `(bandId,
/// trackId)` pair). Set on a cache hit (from the pre-existing cached value)
/// and bumped unconditionally on every successful
/// [TrackDetailData._fetchAndCache]/[TrackDetailData.updateFields] — never
/// on a failed background refresh, since `_refresh()`'s catch branch never
/// reaches that call.
///
/// Copied from [TrackDetailSyncedAt].
class TrackDetailSyncedAtFamily extends Family<DateTime?> {
  /// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
  /// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
  /// cache-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// tracks" + Retry error state).
  /// `bandTrackDetail` cache key's `syncedAt`, mirrored from
  /// `cache_service.dart`'s stored timestamp (family, keyed per `(bandId,
  /// trackId)` pair). Set on a cache hit (from the pre-existing cached value)
  /// and bumped unconditionally on every successful
  /// [TrackDetailData._fetchAndCache]/[TrackDetailData.updateFields] — never
  /// on a failed background refresh, since `_refresh()`'s catch branch never
  /// reaches that call.
  ///
  /// Copied from [TrackDetailSyncedAt].
  const TrackDetailSyncedAtFamily();

  /// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
  /// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
  /// cache-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// tracks" + Retry error state).
  /// `bandTrackDetail` cache key's `syncedAt`, mirrored from
  /// `cache_service.dart`'s stored timestamp (family, keyed per `(bandId,
  /// trackId)` pair). Set on a cache hit (from the pre-existing cached value)
  /// and bumped unconditionally on every successful
  /// [TrackDetailData._fetchAndCache]/[TrackDetailData.updateFields] — never
  /// on a failed background refresh, since `_refresh()`'s catch branch never
  /// reaches that call.
  ///
  /// Copied from [TrackDetailSyncedAt].
  TrackDetailSyncedAtProvider call(String bandId, String trackId) {
    return TrackDetailSyncedAtProvider(bandId, trackId);
  }

  @override
  TrackDetailSyncedAtProvider getProviderOverride(
    covariant TrackDetailSyncedAtProvider provider,
  ) {
    return call(provider.bandId, provider.trackId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'trackDetailSyncedAtProvider';
}

/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
/// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
/// cache-first shape, see `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// tracks" + Retry error state).
/// `bandTrackDetail` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp (family, keyed per `(bandId,
/// trackId)` pair). Set on a cache hit (from the pre-existing cached value)
/// and bumped unconditionally on every successful
/// [TrackDetailData._fetchAndCache]/[TrackDetailData.updateFields] — never
/// on a failed background refresh, since `_refresh()`'s catch branch never
/// reaches that call.
///
/// Copied from [TrackDetailSyncedAt].
class TrackDetailSyncedAtProvider
    extends AutoDisposeNotifierProviderImpl<TrackDetailSyncedAt, DateTime?> {
  /// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
  /// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
  /// cache-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// tracks" + Retry error state).
  /// `bandTrackDetail` cache key's `syncedAt`, mirrored from
  /// `cache_service.dart`'s stored timestamp (family, keyed per `(bandId,
  /// trackId)` pair). Set on a cache hit (from the pre-existing cached value)
  /// and bumped unconditionally on every successful
  /// [TrackDetailData._fetchAndCache]/[TrackDetailData.updateFields] — never
  /// on a failed background refresh, since `_refresh()`'s catch branch never
  /// reaches that call.
  ///
  /// Copied from [TrackDetailSyncedAt].
  TrackDetailSyncedAtProvider(String bandId, String trackId)
    : this._internal(
        () => TrackDetailSyncedAt()
          ..bandId = bandId
          ..trackId = trackId,
        from: trackDetailSyncedAtProvider,
        name: r'trackDetailSyncedAtProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$trackDetailSyncedAtHash,
        dependencies: TrackDetailSyncedAtFamily._dependencies,
        allTransitiveDependencies:
            TrackDetailSyncedAtFamily._allTransitiveDependencies,
        bandId: bandId,
        trackId: trackId,
      );

  TrackDetailSyncedAtProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bandId,
    required this.trackId,
  }) : super.internal();

  final String bandId;
  final String trackId;

  @override
  DateTime? runNotifierBuild(covariant TrackDetailSyncedAt notifier) {
    return notifier.build(bandId, trackId);
  }

  @override
  Override overrideWith(TrackDetailSyncedAt Function() create) {
    return ProviderOverride(
      origin: this,
      override: TrackDetailSyncedAtProvider._internal(
        () => create()
          ..bandId = bandId
          ..trackId = trackId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bandId: bandId,
        trackId: trackId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<TrackDetailSyncedAt, DateTime?>
  createElement() {
    return _TrackDetailSyncedAtProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackDetailSyncedAtProvider &&
        other.bandId == bandId &&
        other.trackId == trackId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bandId.hashCode);
    hash = _SystemHash.combine(hash, trackId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TrackDetailSyncedAtRef on AutoDisposeNotifierProviderRef<DateTime?> {
  /// The parameter `bandId` of this provider.
  String get bandId;

  /// The parameter `trackId` of this provider.
  String get trackId;
}

class _TrackDetailSyncedAtProviderElement
    extends AutoDisposeNotifierProviderElement<TrackDetailSyncedAt, DateTime?>
    with TrackDetailSyncedAtRef {
  _TrackDetailSyncedAtProviderElement(super.provider);

  @override
  String get bandId => (origin as TrackDetailSyncedAtProvider).bandId;
  @override
  String get trackId => (origin as TrackDetailSyncedAtProvider).trackId;
}

String _$trackDetailDataHash() => r'f71cebc8a0a35ff292f61a952218895a7eda4ab9';

abstract class _$TrackDetailData
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final String bandId;
  late final String trackId;

  FutureOr<Map<String, dynamic>> build(String bandId, String trackId);
}

/// See also [TrackDetailData].
@ProviderFor(TrackDetailData)
const trackDetailDataProvider = TrackDetailDataFamily();

/// See also [TrackDetailData].
class TrackDetailDataFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// See also [TrackDetailData].
  const TrackDetailDataFamily();

  /// See also [TrackDetailData].
  TrackDetailDataProvider call(String bandId, String trackId) {
    return TrackDetailDataProvider(bandId, trackId);
  }

  @override
  TrackDetailDataProvider getProviderOverride(
    covariant TrackDetailDataProvider provider,
  ) {
    return call(provider.bandId, provider.trackId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'trackDetailDataProvider';
}

/// See also [TrackDetailData].
class TrackDetailDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          TrackDetailData,
          Map<String, dynamic>
        > {
  /// See also [TrackDetailData].
  TrackDetailDataProvider(String bandId, String trackId)
    : this._internal(
        () => TrackDetailData()
          ..bandId = bandId
          ..trackId = trackId,
        from: trackDetailDataProvider,
        name: r'trackDetailDataProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$trackDetailDataHash,
        dependencies: TrackDetailDataFamily._dependencies,
        allTransitiveDependencies:
            TrackDetailDataFamily._allTransitiveDependencies,
        bandId: bandId,
        trackId: trackId,
      );

  TrackDetailDataProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bandId,
    required this.trackId,
  }) : super.internal();

  final String bandId;
  final String trackId;

  @override
  FutureOr<Map<String, dynamic>> runNotifierBuild(
    covariant TrackDetailData notifier,
  ) {
    return notifier.build(bandId, trackId);
  }

  @override
  Override overrideWith(TrackDetailData Function() create) {
    return ProviderOverride(
      origin: this,
      override: TrackDetailDataProvider._internal(
        () => create()
          ..bandId = bandId
          ..trackId = trackId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bandId: bandId,
        trackId: trackId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<TrackDetailData, Map<String, dynamic>>
  createElement() {
    return _TrackDetailDataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackDetailDataProvider &&
        other.bandId == bandId &&
        other.trackId == trackId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bandId.hashCode);
    hash = _SystemHash.combine(hash, trackId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TrackDetailDataRef
    on AutoDisposeAsyncNotifierProviderRef<Map<String, dynamic>> {
  /// The parameter `bandId` of this provider.
  String get bandId;

  /// The parameter `trackId` of this provider.
  String get trackId;
}

class _TrackDetailDataProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          TrackDetailData,
          Map<String, dynamic>
        >
    with TrackDetailDataRef {
  _TrackDetailDataProviderElement(super.provider);

  @override
  String get bandId => (origin as TrackDetailDataProvider).bandId;
  @override
  String get trackId => (origin as TrackDetailDataProvider).trackId;
}

String _$selectedBandIdFilterHash() =>
    r'0289734a68cc96087672605cf5ffa5e9208813a9';

/// The band the global Tracks tab's list is currently filtered to; `null`
/// means "all bands". Plain (non-family) provider — its notifier's `state`
/// is set directly by `TracksScreen`'s filter dropdown.
///
/// Copied from [SelectedBandIdFilter].
@ProviderFor(SelectedBandIdFilter)
final selectedBandIdFilterProvider =
    AutoDisposeNotifierProvider<SelectedBandIdFilter, String?>.internal(
      SelectedBandIdFilter.new,
      name: r'selectedBandIdFilterProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedBandIdFilterHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedBandIdFilter = AutoDisposeNotifier<String?>;
String _$userTracksSyncedAtHash() =>
    r'27c4a9b97d58e9e5c7d6eb83243aca150baaa4f1';

/// Cache-first `GET /api/track/list` data spanning every band the user
/// belongs to, optionally narrowed by [SelectedBandIdFilter] (mirrors
/// [TrackListData]'s cache-first shape, but non-family — [build] watches
/// [selectedBandIdFilterProvider] directly, so changing the filter
/// automatically triggers a full rebuild with the new cache key/fetch).
/// `userTracks` cache key's `syncedAt`, mirrored from `cache_service.dart`'s
/// stored timestamp (plain, non-family — mirrors [HomepageSyncedAt]'s
/// shape). Set on a cache hit (from the pre-existing cached value) and
/// bumped unconditionally on every successful
/// [UserTracksListData._fetchAndCache] — never on a failed background
/// refresh, since `_refresh()`'s catch branch never reaches that call.
///
/// Copied from [UserTracksSyncedAt].
@ProviderFor(UserTracksSyncedAt)
final userTracksSyncedAtProvider =
    AutoDisposeNotifierProvider<UserTracksSyncedAt, DateTime?>.internal(
      UserTracksSyncedAt.new,
      name: r'userTracksSyncedAtProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userTracksSyncedAtHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserTracksSyncedAt = AutoDisposeNotifier<DateTime?>;
String _$userTracksListDataHash() =>
    r'75d98e73d999a7f939c36a2faa7eab2f1e8a4811';

/// See also [UserTracksListData].
@ProviderFor(UserTracksListData)
final userTracksListDataProvider =
    AutoDisposeAsyncNotifierProvider<
      UserTracksListData,
      List<Map<String, dynamic>>
    >.internal(
      UserTracksListData.new,
      name: r'userTracksListDataProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userTracksListDataHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserTracksListData =
    AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
