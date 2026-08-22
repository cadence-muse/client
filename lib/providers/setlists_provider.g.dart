// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setlists_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$setlistListDataHash() => r'abc86394763d440110ea12a151d4ce7d65a417d9';

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

abstract class _$SetlistListData
    extends BuildlessAutoDisposeAsyncNotifier<List<Map<String, dynamic>>> {
  late final String bandId;

  FutureOr<List<Map<String, dynamic>>> build(String bandId);
}

/// Online-first `GET /api/band/{bandId}/setlist/list` data, keyed per band
/// (D-01/D-03/D-06; family provider — mirrors [BandsListData]'s online-first
/// shape, see `bands_provider.dart`).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Failed to load setlists" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
///
/// Copied from [SetlistListData].
@ProviderFor(SetlistListData)
const setlistListDataProvider = SetlistListDataFamily();

/// Online-first `GET /api/band/{bandId}/setlist/list` data, keyed per band
/// (D-01/D-03/D-06; family provider — mirrors [BandsListData]'s online-first
/// shape, see `bands_provider.dart`).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Failed to load setlists" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
///
/// Copied from [SetlistListData].
class SetlistListDataFamily
    extends Family<AsyncValue<List<Map<String, dynamic>>>> {
  /// Online-first `GET /api/band/{bandId}/setlist/list` data, keyed per band
  /// (D-01/D-03/D-06; family provider — mirrors [BandsListData]'s online-first
  /// shape, see `bands_provider.dart`).
  ///
  /// On [build], when [isOnlineProvider] is true, a fresh fetch is always
  /// attempted first — a populated cache is not consulted on the happy path.
  /// If that fetch throws, the cache is checked as a silent fallback (D-03; no
  /// distinct error surfaced when a cache hit exists) and only rethrows (as an
  /// [AsyncError], driving "Failed to load setlists" + Retry) when there's
  /// nothing cached either. When offline, cached data is served directly with
  /// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
  /// ever been cached (D-06) — recovery from that state is automatic the
  /// moment [isOnlineProvider] flips back to true, since [build] re-watches it.
  ///
  /// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
  /// a second call while one is already in flight reuses the same [Future]
  /// rather than firing a second network request.
  ///
  /// Copied from [SetlistListData].
  const SetlistListDataFamily();

  /// Online-first `GET /api/band/{bandId}/setlist/list` data, keyed per band
  /// (D-01/D-03/D-06; family provider — mirrors [BandsListData]'s online-first
  /// shape, see `bands_provider.dart`).
  ///
  /// On [build], when [isOnlineProvider] is true, a fresh fetch is always
  /// attempted first — a populated cache is not consulted on the happy path.
  /// If that fetch throws, the cache is checked as a silent fallback (D-03; no
  /// distinct error surfaced when a cache hit exists) and only rethrows (as an
  /// [AsyncError], driving "Failed to load setlists" + Retry) when there's
  /// nothing cached either. When offline, cached data is served directly with
  /// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
  /// ever been cached (D-06) — recovery from that state is automatic the
  /// moment [isOnlineProvider] flips back to true, since [build] re-watches it.
  ///
  /// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
  /// a second call while one is already in flight reuses the same [Future]
  /// rather than firing a second network request.
  ///
  /// Copied from [SetlistListData].
  SetlistListDataProvider call(String bandId) {
    return SetlistListDataProvider(bandId);
  }

  @override
  SetlistListDataProvider getProviderOverride(
    covariant SetlistListDataProvider provider,
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
  String? get name => r'setlistListDataProvider';
}

/// Online-first `GET /api/band/{bandId}/setlist/list` data, keyed per band
/// (D-01/D-03/D-06; family provider — mirrors [BandsListData]'s online-first
/// shape, see `bands_provider.dart`).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Failed to load setlists" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
///
/// Copied from [SetlistListData].
class SetlistListDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          SetlistListData,
          List<Map<String, dynamic>>
        > {
  /// Online-first `GET /api/band/{bandId}/setlist/list` data, keyed per band
  /// (D-01/D-03/D-06; family provider — mirrors [BandsListData]'s online-first
  /// shape, see `bands_provider.dart`).
  ///
  /// On [build], when [isOnlineProvider] is true, a fresh fetch is always
  /// attempted first — a populated cache is not consulted on the happy path.
  /// If that fetch throws, the cache is checked as a silent fallback (D-03; no
  /// distinct error surfaced when a cache hit exists) and only rethrows (as an
  /// [AsyncError], driving "Failed to load setlists" + Retry) when there's
  /// nothing cached either. When offline, cached data is served directly with
  /// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
  /// ever been cached (D-06) — recovery from that state is automatic the
  /// moment [isOnlineProvider] flips back to true, since [build] re-watches it.
  ///
  /// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
  /// a second call while one is already in flight reuses the same [Future]
  /// rather than firing a second network request.
  ///
  /// Copied from [SetlistListData].
  SetlistListDataProvider(String bandId)
    : this._internal(
        () => SetlistListData()..bandId = bandId,
        from: setlistListDataProvider,
        name: r'setlistListDataProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$setlistListDataHash,
        dependencies: SetlistListDataFamily._dependencies,
        allTransitiveDependencies:
            SetlistListDataFamily._allTransitiveDependencies,
        bandId: bandId,
      );

  SetlistListDataProvider._internal(
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
    covariant SetlistListData notifier,
  ) {
    return notifier.build(bandId);
  }

  @override
  Override overrideWith(SetlistListData Function() create) {
    return ProviderOverride(
      origin: this,
      override: SetlistListDataProvider._internal(
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
    SetlistListData,
    List<Map<String, dynamic>>
  >
  createElement() {
    return _SetlistListDataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SetlistListDataProvider && other.bandId == bandId;
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
mixin SetlistListDataRef
    on AutoDisposeAsyncNotifierProviderRef<List<Map<String, dynamic>>> {
  /// The parameter `bandId` of this provider.
  String get bandId;
}

class _SetlistListDataProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          SetlistListData,
          List<Map<String, dynamic>>
        >
    with SetlistListDataRef {
  _SetlistListDataProviderElement(super.provider);

  @override
  String get bandId => (origin as SetlistListDataProvider).bandId;
}

String _$setlistDetailDataHash() => r'ba9793bce43fda5378fde526b9f4d36013336889';

abstract class _$SetlistDetailData
    extends BuildlessAutoDisposeAsyncNotifier<Map<String, dynamic>> {
  late final String bandId;
  late final String setlistId;

  FutureOr<Map<String, dynamic>> build(String bandId, String setlistId);
}

/// Online-first `GET /api/band/{bandId}/setlist/{setlistId}` data (D-01/
/// D-03/D-06), keyed per `(bandId, setlistId)` pair (family provider —
/// mirrors [BandDetailData]'s online-first shape, see `bands_provider.dart`).
///
/// Mirrors [SetlistListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not consulted
/// on the happy path); a failed online fetch falls back to cache silently
/// (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `SetlistDetailScreen`.
///
/// Copied from [SetlistDetailData].
@ProviderFor(SetlistDetailData)
const setlistDetailDataProvider = SetlistDetailDataFamily();

/// Online-first `GET /api/band/{bandId}/setlist/{setlistId}` data (D-01/
/// D-03/D-06), keyed per `(bandId, setlistId)` pair (family provider —
/// mirrors [BandDetailData]'s online-first shape, see `bands_provider.dart`).
///
/// Mirrors [SetlistListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not consulted
/// on the happy path); a failed online fetch falls back to cache silently
/// (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `SetlistDetailScreen`.
///
/// Copied from [SetlistDetailData].
class SetlistDetailDataFamily extends Family<AsyncValue<Map<String, dynamic>>> {
  /// Online-first `GET /api/band/{bandId}/setlist/{setlistId}` data (D-01/
  /// D-03/D-06), keyed per `(bandId, setlistId)` pair (family provider —
  /// mirrors [BandDetailData]'s online-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [SetlistListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not consulted
  /// on the happy path); a failed online fetch falls back to cache silently
  /// (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `SetlistDetailScreen`.
  ///
  /// Copied from [SetlistDetailData].
  const SetlistDetailDataFamily();

  /// Online-first `GET /api/band/{bandId}/setlist/{setlistId}` data (D-01/
  /// D-03/D-06), keyed per `(bandId, setlistId)` pair (family provider —
  /// mirrors [BandDetailData]'s online-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [SetlistListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not consulted
  /// on the happy path); a failed online fetch falls back to cache silently
  /// (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `SetlistDetailScreen`.
  ///
  /// Copied from [SetlistDetailData].
  SetlistDetailDataProvider call(String bandId, String setlistId) {
    return SetlistDetailDataProvider(bandId, setlistId);
  }

  @override
  SetlistDetailDataProvider getProviderOverride(
    covariant SetlistDetailDataProvider provider,
  ) {
    return call(provider.bandId, provider.setlistId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'setlistDetailDataProvider';
}

/// Online-first `GET /api/band/{bandId}/setlist/{setlistId}` data (D-01/
/// D-03/D-06), keyed per `(bandId, setlistId)` pair (family provider —
/// mirrors [BandDetailData]'s online-first shape, see `bands_provider.dart`).
///
/// Mirrors [SetlistListData]'s online-first shape exactly: when online, a
/// fresh fetch is always attempted first (a populated cache is not consulted
/// on the happy path); a failed online fetch falls back to cache silently
/// (D-03); offline serves cache directly or throws
/// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
/// tab-switch wiring is needed here (D-02) — this `autoDispose` family
/// provider already rebuilds fresh on every `Navigator.push` into
/// `SetlistDetailScreen`.
///
/// Copied from [SetlistDetailData].
class SetlistDetailDataProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          SetlistDetailData,
          Map<String, dynamic>
        > {
  /// Online-first `GET /api/band/{bandId}/setlist/{setlistId}` data (D-01/
  /// D-03/D-06), keyed per `(bandId, setlistId)` pair (family provider —
  /// mirrors [BandDetailData]'s online-first shape, see `bands_provider.dart`).
  ///
  /// Mirrors [SetlistListData]'s online-first shape exactly: when online, a
  /// fresh fetch is always attempted first (a populated cache is not consulted
  /// on the happy path); a failed online fetch falls back to cache silently
  /// (D-03); offline serves cache directly or throws
  /// [OfflineNoCacheException] if nothing has ever been cached (D-06). No
  /// tab-switch wiring is needed here (D-02) — this `autoDispose` family
  /// provider already rebuilds fresh on every `Navigator.push` into
  /// `SetlistDetailScreen`.
  ///
  /// Copied from [SetlistDetailData].
  SetlistDetailDataProvider(String bandId, String setlistId)
    : this._internal(
        () => SetlistDetailData()
          ..bandId = bandId
          ..setlistId = setlistId,
        from: setlistDetailDataProvider,
        name: r'setlistDetailDataProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$setlistDetailDataHash,
        dependencies: SetlistDetailDataFamily._dependencies,
        allTransitiveDependencies:
            SetlistDetailDataFamily._allTransitiveDependencies,
        bandId: bandId,
        setlistId: setlistId,
      );

  SetlistDetailDataProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bandId,
    required this.setlistId,
  }) : super.internal();

  final String bandId;
  final String setlistId;

  @override
  FutureOr<Map<String, dynamic>> runNotifierBuild(
    covariant SetlistDetailData notifier,
  ) {
    return notifier.build(bandId, setlistId);
  }

  @override
  Override overrideWith(SetlistDetailData Function() create) {
    return ProviderOverride(
      origin: this,
      override: SetlistDetailDataProvider._internal(
        () => create()
          ..bandId = bandId
          ..setlistId = setlistId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bandId: bandId,
        setlistId: setlistId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    SetlistDetailData,
    Map<String, dynamic>
  >
  createElement() {
    return _SetlistDetailDataProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SetlistDetailDataProvider &&
        other.bandId == bandId &&
        other.setlistId == setlistId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bandId.hashCode);
    hash = _SystemHash.combine(hash, setlistId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SetlistDetailDataRef
    on AutoDisposeAsyncNotifierProviderRef<Map<String, dynamic>> {
  /// The parameter `bandId` of this provider.
  String get bandId;

  /// The parameter `setlistId` of this provider.
  String get setlistId;
}

class _SetlistDetailDataProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          SetlistDetailData,
          Map<String, dynamic>
        >
    with SetlistDetailDataRef {
  _SetlistDetailDataProviderElement(super.provider);

  @override
  String get bandId => (origin as SetlistDetailDataProvider).bandId;
  @override
  String get setlistId => (origin as SetlistDetailDataProvider).setlistId;
}

String _$selectedSetlistBandIdFilterHash() =>
    r'fdc163c6ec512b866d766b097d7857cd62bb306c';

/// The band the global Setlists tab's list is currently filtered to; `null`
/// means "all bands". Plain (non-family) provider — its notifier's `state`
/// is set directly by `SetlistsScreen`'s filter dropdown.
///
/// Named `SelectedSetlistBandIdFilter`, not `SelectedBandIdFilter` — the
/// latter is already defined in `tracks_provider.dart`, and
/// `add_setlist_tracks_dialog.dart` imports both provider files. A same-named
/// top-level identifier in both would be a Dart ambiguous-import compile
/// error, so this provider is distinctly named despite being functionally
/// identical to Track's filter (see `04-05-PLAN.md`'s naming-deviation
/// note).
///
/// Copied from [SelectedSetlistBandIdFilter].
@ProviderFor(SelectedSetlistBandIdFilter)
final selectedSetlistBandIdFilterProvider =
    AutoDisposeNotifierProvider<SelectedSetlistBandIdFilter, String?>.internal(
      SelectedSetlistBandIdFilter.new,
      name: r'selectedSetlistBandIdFilterProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedSetlistBandIdFilterHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedSetlistBandIdFilter = AutoDisposeNotifier<String?>;
String _$userSetlistsListDataHash() =>
    r'ed1a3c3fafaafcc5d1db134d11f8759b0668c3a9';

/// Online-first `GET /api/setlist/list` data spanning every band the user
/// belongs to, optionally narrowed by [SelectedSetlistBandIdFilter] (D-01/
/// D-03/D-06; mirrors [UserTracksListData]'s online-first shape, but
/// non-family — [build] watches [selectedSetlistBandIdFilterProvider]
/// directly, so changing the filter automatically triggers a full rebuild
/// with the new cache key/fetch).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError]) when there's nothing cached either. When offline, cached
/// data is served directly with zero network calls, or
/// [OfflineNoCacheException] is thrown if nothing has ever been cached
/// (D-06) — recovery from that state is automatic the moment
/// [isOnlineProvider] flips back to true, since [build] re-watches it.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
///
/// Copied from [UserSetlistsListData].
@ProviderFor(UserSetlistsListData)
final userSetlistsListDataProvider =
    AutoDisposeAsyncNotifierProvider<
      UserSetlistsListData,
      List<Map<String, dynamic>>
    >.internal(
      UserSetlistsListData.new,
      name: r'userSetlistsListDataProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userSetlistsListDataHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserSetlistsListData =
    AutoDisposeAsyncNotifier<List<Map<String, dynamic>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
