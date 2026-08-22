// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bands_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bandsListDataHash() => r'f3820c450ebb65753fe239bed97cb9f4d770fad0';

/// Online-first `GET /api/band/list` data (D-01/D-03/D-06).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load bands" + Retry) when there's nothing
/// cached either. When offline, cached data is served directly with zero
/// network calls, or [OfflineNoCacheException] is thrown if nothing has ever
/// been cached (D-06) — recovery from that state is automatic the moment
/// [isOnlineProvider] flips back to true, since [build] re-watches it.
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
String _$bandDetailDataHash() => r'0815a209e7493b3b40a8289c50ccf4a6da2b4036';

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

abstract class _$BandDetailData
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final String bandId;

  FutureOr<Map<String, dynamic>> build(String bandId);
}

/// Online-first `GET /api/band/{bandId}` data (D-01/D-03/D-06), keyed per
/// band (this project's first family provider — [build]'s extra `bandId`
/// parameter is auto-detected by riverpod_generator as the family key).
///
/// Mirrors [BandsListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not
/// consulted on the happy path); a failed online fetch falls back to cache
/// silently (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `BandDetailScreen`.
///
/// Copied from [BandDetailData].
@ProviderFor(BandDetailData)
const bandDetailDataProvider = BandDetailDataFamily();

/// Online-first `GET /api/band/{bandId}` data (D-01/D-03/D-06), keyed per
/// band (this project's first family provider — [build]'s extra `bandId`
/// parameter is auto-detected by riverpod_generator as the family key).
///
/// Mirrors [BandsListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not
/// consulted on the happy path); a failed online fetch falls back to cache
/// silently (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `BandDetailScreen`.
///
/// Copied from [BandDetailData].
class BandDetailDataFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// Online-first `GET /api/band/{bandId}` data (D-01/D-03/D-06), keyed per
  /// band (this project's first family provider — [build]'s extra `bandId`
  /// parameter is auto-detected by riverpod_generator as the family key).
  ///
  /// Mirrors [BandsListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not
  /// consulted on the happy path); a failed online fetch falls back to cache
  /// silently (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `BandDetailScreen`.
  ///
  /// Copied from [BandDetailData].
  const BandDetailDataFamily();

  /// Online-first `GET /api/band/{bandId}` data (D-01/D-03/D-06), keyed per
  /// band (this project's first family provider — [build]'s extra `bandId`
  /// parameter is auto-detected by riverpod_generator as the family key).
  ///
  /// Mirrors [BandsListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not
  /// consulted on the happy path); a failed online fetch falls back to cache
  /// silently (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `BandDetailScreen`.
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

/// Online-first `GET /api/band/{bandId}` data (D-01/D-03/D-06), keyed per
/// band (this project's first family provider — [build]'s extra `bandId`
/// parameter is auto-detected by riverpod_generator as the family key).
///
/// Mirrors [BandsListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not
/// consulted on the happy path); a failed online fetch falls back to cache
/// silently (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `BandDetailScreen`.
///
/// Copied from [BandDetailData].
class BandDetailDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          BandDetailData,
          Map<String, dynamic>
        > {
  /// Online-first `GET /api/band/{bandId}` data (D-01/D-03/D-06), keyed per
  /// band (this project's first family provider — [build]'s extra `bandId`
  /// parameter is auto-detected by riverpod_generator as the family key).
  ///
  /// Mirrors [BandsListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not
  /// consulted on the happy path); a failed online fetch falls back to cache
  /// silently (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `BandDetailScreen`.
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
