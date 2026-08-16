// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$trackListDataHash() => r'091c7e859bc360c7650038b49ff3dd1fca908930';

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

abstract class _$TrackListData
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final String bandId;

  FutureOr<List<Map<String, dynamic>>> build(String bandId);
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
///
/// Copied from [TrackListData].
@ProviderFor(TrackListData)
const trackListDataProvider = TrackListDataFamily();

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
///
/// Copied from [TrackListData].
class TrackListDataFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
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
  ///
  /// Copied from [TrackListData].
  const TrackListDataFamily();

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
  ///
  /// Copied from [TrackListData].
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
///
/// Copied from [TrackListData].
class TrackListDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          TrackListData,
          List<Map<String, dynamic>>
        > {
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
  ///
  /// Copied from [TrackListData].
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

String _$trackDetailDataHash() => r'9b8c6e15a0957fc78d9d84aea32b93e6e206e295';

abstract class _$TrackDetailData
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final String bandId;
  late final String trackId;

  FutureOr<Map<String, dynamic>> build(String bandId, String trackId);
}

/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
/// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
/// cache-first shape, see `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// tracks" + Retry error state).
///
/// Copied from [TrackDetailData].
@ProviderFor(TrackDetailData)
const trackDetailDataProvider = TrackDetailDataFamily();

/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
/// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
/// cache-first shape, see `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// tracks" + Retry error state).
///
/// Copied from [TrackDetailData].
class TrackDetailDataFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
  /// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
  /// cache-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// tracks" + Retry error state).
  ///
  /// Copied from [TrackDetailData].
  const TrackDetailDataFamily();

  /// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
  /// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
  /// cache-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// tracks" + Retry error state).
  ///
  /// Copied from [TrackDetailData].
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

/// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
/// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
/// cache-first shape, see `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s cache-first shape: cache hit returns
/// immediately with a silent background refresh; cache miss fetches inline
/// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
/// tracks" + Retry error state).
///
/// Copied from [TrackDetailData].
class TrackDetailDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          TrackDetailData,
          Map<String, dynamic>
        > {
  /// Cache-first `GET /api/band/{bandId}/track/{trackId}` data, keyed per
  /// `(bandId, trackId)` pair (family provider — mirrors [BandDetailData]'s
  /// cache-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s cache-first shape: cache hit returns
  /// immediately with a silent background refresh; cache miss fetches inline
  /// (any [ApiException] becomes an [AsyncError], driving the "Couldn't load
  /// tracks" + Retry error state).
  ///
  /// Copied from [TrackDetailData].
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

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
