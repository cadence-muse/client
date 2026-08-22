// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homepage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homepageDataHash() => r'd04b1e6feb258cc2dc44279dbe7d98cf39bdd503';

/// Online-first `GET /api/homepage` data (D-01/D-03/D-06).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load home" + Retry) when there's nothing
/// cached either. When offline, cached data is served directly with zero
/// network calls, or [OfflineNoCacheException] is thrown if nothing has ever
/// been cached (D-06) — recovery from that state is automatic the moment
/// [isOnlineProvider] flips back to true, since [build] re-watches it. This
/// provider has no `_version` guard (unlike bands/tracks/setlists) — there
/// are no local-mutation methods here to race against.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
///
/// Copied from [HomepageData].
@ProviderFor(HomepageData)
final homepageDataProvider =
    AutoDisposeAsyncNotifierProvider<
      HomepageData,
      Map<String, dynamic>
    >.internal(
      HomepageData.new,
      name: r'homepageDataProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$homepageDataHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$HomepageData = AutoDisposeAsyncNotifier<Map<String, dynamic>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
