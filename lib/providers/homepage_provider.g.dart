// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'homepage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homepageDataHash() => r'bcdbd3a466253bc4e9f87135fc2fadf2c35294b6';

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
