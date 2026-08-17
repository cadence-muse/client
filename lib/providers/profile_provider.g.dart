// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileSyncedAtHash() => r'568ee3fe423cc7165e0a04bb6d638143360401df';

/// Cache-first `GET /api/me` data.
///
/// On [build], cached data (if present) is returned immediately with a
/// background refresh kicked off silently (no loading spinner, no error
/// surfaced if the background refresh fails — D-04/D-06 in
/// `01-CONTEXT.md`). With no cache, the network fetch happens inline and any
/// [ApiException] becomes an [AsyncError], which is what drives the
/// "Couldn't load profile" + Retry error state.
///
/// [refresh] (the UI's pull-to-refresh / refresh-button entry point) dedupes
/// concurrent calls: a second call while one is already in flight reuses the
/// same [Future] rather than firing a second network request.
/// D-05/D-06: `profile` cache key's `syncedAt`, mirrored from
/// `cache_service.dart`'s stored timestamp. Set on a cache hit (from the
/// pre-existing cached value) and bumped unconditionally on every successful
/// [ProfileData._fetchAndCache] — never on a failed background refresh,
/// since `_refresh()`'s catch branch never reaches that call.
///
/// Copied from [ProfileSyncedAt].
@ProviderFor(ProfileSyncedAt)
final profileSyncedAtProvider =
    AutoDisposeNotifierProvider<ProfileSyncedAt, DateTime?>.internal(
      ProfileSyncedAt.new,
      name: r'profileSyncedAtProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$profileSyncedAtHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProfileSyncedAt = AutoDisposeNotifier<DateTime?>;
String _$profileDataHash() => r'6bc11d208026f067ab10df8c1ab9e6994b6984af';

/// See also [ProfileData].
@ProviderFor(ProfileData)
final profileDataProvider =
    AutoDisposeAsyncNotifierProvider<
      ProfileData,
      Map<String, dynamic>
    >.internal(
      ProfileData.new,
      name: r'profileDataProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$profileDataHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ProfileData = AutoDisposeAsyncNotifier<Map<String, dynamic>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
