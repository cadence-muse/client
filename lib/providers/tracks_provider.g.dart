// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracks_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$trackListDataHash() => r'c3106edb1e2ae930b76c907c5c2a9ff579911ac2';

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

/// Online-first `GET /api/band/{bandId}/track/list` data (D-01/D-03/D-06),
/// keyed per band (family provider — mirrors [TrackListData]'s counterpart
/// [BandsListData] in `bands_provider.dart`).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load tracks" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches
/// it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
///
/// Copied from [TrackListData].
@ProviderFor(TrackListData)
const trackListDataProvider = TrackListDataFamily();

/// Online-first `GET /api/band/{bandId}/track/list` data (D-01/D-03/D-06),
/// keyed per band (family provider — mirrors [TrackListData]'s counterpart
/// [BandsListData] in `bands_provider.dart`).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load tracks" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches
/// it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
///
/// Copied from [TrackListData].
class TrackListDataFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// Online-first `GET /api/band/{bandId}/track/list` data (D-01/D-03/D-06),
  /// keyed per band (family provider — mirrors [TrackListData]'s counterpart
  /// [BandsListData] in `bands_provider.dart`).
  ///
  /// On [build], when [isOnlineProvider] is true, a fresh fetch is always
  /// attempted first — a populated cache is not consulted on the happy path.
  /// If that fetch throws, the cache is checked as a silent fallback (D-03; no
  /// distinct error surfaced when a cache hit exists) and only rethrows (as an
  /// [AsyncError], driving "Couldn't load tracks" + Retry) when there's
  /// nothing cached either. When offline, cached data is served directly with
  /// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
  /// ever been cached (D-06) — recovery from that state is automatic the
  /// moment [isOnlineProvider] flips back to true, since [build] re-watches
  /// it.
  ///
  /// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
  /// a second call while one is already in flight reuses the same [Future]
  /// rather than firing a second network request.
  ///
  /// Copied from [TrackListData].
  const TrackListDataFamily();

  /// Online-first `GET /api/band/{bandId}/track/list` data (D-01/D-03/D-06),
  /// keyed per band (family provider — mirrors [TrackListData]'s counterpart
  /// [BandsListData] in `bands_provider.dart`).
  ///
  /// On [build], when [isOnlineProvider] is true, a fresh fetch is always
  /// attempted first — a populated cache is not consulted on the happy path.
  /// If that fetch throws, the cache is checked as a silent fallback (D-03; no
  /// distinct error surfaced when a cache hit exists) and only rethrows (as an
  /// [AsyncError], driving "Couldn't load tracks" + Retry) when there's
  /// nothing cached either. When offline, cached data is served directly with
  /// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
  /// ever been cached (D-06) — recovery from that state is automatic the
  /// moment [isOnlineProvider] flips back to true, since [build] re-watches
  /// it.
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

/// Online-first `GET /api/band/{bandId}/track/list` data (D-01/D-03/D-06),
/// keyed per band (family provider — mirrors [TrackListData]'s counterpart
/// [BandsListData] in `bands_provider.dart`).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load tracks" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches
/// it.
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
  /// Online-first `GET /api/band/{bandId}/track/list` data (D-01/D-03/D-06),
  /// keyed per band (family provider — mirrors [TrackListData]'s counterpart
  /// [BandsListData] in `bands_provider.dart`).
  ///
  /// On [build], when [isOnlineProvider] is true, a fresh fetch is always
  /// attempted first — a populated cache is not consulted on the happy path.
  /// If that fetch throws, the cache is checked as a silent fallback (D-03; no
  /// distinct error surfaced when a cache hit exists) and only rethrows (as an
  /// [AsyncError], driving "Couldn't load tracks" + Retry) when there's
  /// nothing cached either. When offline, cached data is served directly with
  /// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
  /// ever been cached (D-06) — recovery from that state is automatic the
  /// moment [isOnlineProvider] flips back to true, since [build] re-watches
  /// it.
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

String _$trackDetailDataHash() => r'2ebec31b1e8aed8fe514effdd7fb360a39b8bcaa';

abstract class _$TrackDetailData
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final String bandId;
  late final String trackId;

  FutureOr<Map<String, dynamic>> build(String bandId, String trackId);
}

/// Online-first `GET /api/band/{bandId}/track/{trackId}` data
/// (D-01/D-03/D-06), keyed per `(bandId, trackId)` pair (family provider —
/// mirrors [TrackDetailData]'s counterpart [BandDetailData] in
/// `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not
/// consulted on the happy path); a failed online fetch falls back to cache
/// silently (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `TrackDetailScreen`.
///
/// Copied from [TrackDetailData].
@ProviderFor(TrackDetailData)
const trackDetailDataProvider = TrackDetailDataFamily();

/// Online-first `GET /api/band/{bandId}/track/{trackId}` data
/// (D-01/D-03/D-06), keyed per `(bandId, trackId)` pair (family provider —
/// mirrors [TrackDetailData]'s counterpart [BandDetailData] in
/// `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not
/// consulted on the happy path); a failed online fetch falls back to cache
/// silently (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `TrackDetailScreen`.
///
/// Copied from [TrackDetailData].
class TrackDetailDataFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// Online-first `GET /api/band/{bandId}/track/{trackId}` data
  /// (D-01/D-03/D-06), keyed per `(bandId, trackId)` pair (family provider —
  /// mirrors [TrackDetailData]'s counterpart [BandDetailData] in
  /// `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not
  /// consulted on the happy path); a failed online fetch falls back to cache
  /// silently (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `TrackDetailScreen`.
  ///
  /// Copied from [TrackDetailData].
  const TrackDetailDataFamily();

  /// Online-first `GET /api/band/{bandId}/track/{trackId}` data
  /// (D-01/D-03/D-06), keyed per `(bandId, trackId)` pair (family provider —
  /// mirrors [TrackDetailData]'s counterpart [BandDetailData] in
  /// `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not
  /// consulted on the happy path); a failed online fetch falls back to cache
  /// silently (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `TrackDetailScreen`.
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

/// Online-first `GET /api/band/{bandId}/track/{trackId}` data
/// (D-01/D-03/D-06), keyed per `(bandId, trackId)` pair (family provider —
/// mirrors [TrackDetailData]'s counterpart [BandDetailData] in
/// `bands_provider.dart`).
///
/// Mirrors [TrackListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not
/// consulted on the happy path); a failed online fetch falls back to cache
/// silently (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `TrackDetailScreen`.
///
/// Copied from [TrackDetailData].
class TrackDetailDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          TrackDetailData,
          Map<String, dynamic>
        > {
  /// Online-first `GET /api/band/{bandId}/track/{trackId}` data
  /// (D-01/D-03/D-06), keyed per `(bandId, trackId)` pair (family provider —
  /// mirrors [TrackDetailData]'s counterpart [BandDetailData] in
  /// `bands_provider.dart`).
  ///
  /// Mirrors [TrackListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not
  /// consulted on the happy path); a failed online fetch falls back to cache
  /// silently (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `TrackDetailScreen`.
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
String _$userTracksListDataHash() =>
    r'2eeb949360a8f1ec746902d7e6ec0ef546545397';

/// Online-first `GET /api/track/list` data spanning every band the user
/// belongs to, optionally narrowed by [SelectedBandIdFilter] (D-01/D-03/D-06;
/// mirrors [TrackListData]'s online-first shape, but non-family — [build]
/// watches [selectedBandIdFilterProvider] directly, so changing the filter
/// automatically triggers a full rebuild with the new cache key/fetch).
///
/// This is the provider backing the cross-band Tracks tab (tab index 2) — a
/// `ref.listen(selectedTabIndexProvider, ...)` in `TracksScreen` invalidates
/// it on every re-selection of the Tracks tab (D-01), same shape as
/// `BandsScreen`'s wiring in `bands_screen.dart`.
///
/// Copied from [UserTracksListData].
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
