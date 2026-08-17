// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homepage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homepageSyncedAtHash() => r'50ae2aca0da4972743ccd7f2d23bef48a10c1257';

/// Cache-first `GET /api/homepage` data.
///
/// On [build], cached data (if present) is returned immediately with a
/// background refresh kicked off silently (no loading spinner, no error
/// surfaced if the background refresh fails — mirrors [ProfileData]'s
/// cache-first pattern). With no cache, the network fetch happens inline and
/// any [ApiException] becomes an [AsyncError], which is what drives the
/// "Couldn't load home" + Retry error state.
///
/// [refresh] (the UI's refresh-button entry point) dedupes concurrent calls:
/// a second call while one is already in flight reuses the same [Future]
/// rather than firing a second network request.
/// D-05/D-06: `homepage` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp. Set on a cache hit (from the
/// pre-existing cached value) and bumped unconditionally on every successful
/// [HomepageData._fetchAndCache] — never on a failed background refresh,
/// since `_refresh()`'s catch branch never reaches that call.
///
/// Copied from [HomepageSyncedAt].
@ProviderFor(HomepageSyncedAt)
final homepageSyncedAtProvider =
    AutoDisposeNotifierProvider<HomepageSyncedAt, DateTime?>.internal(
      HomepageSyncedAt.new,
      name: r'homepageSyncedAtProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$homepageSyncedAtHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$HomepageSyncedAt = AutoDisposeNotifier<DateTime?>;
String _$homepageDataHash() => r'ba02014a71cb2eccba6ecddc4ba9dafa999baa53';

/// See also [HomepageData].
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
