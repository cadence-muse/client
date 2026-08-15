// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bands_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bandsListDataHash() => r'7691081a36b77d61ae5258d5dcce63d62b9cb21a';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
