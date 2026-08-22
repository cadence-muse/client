// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileDataHash() => r'1e3f5f6c9a7b0979678892f72f53be2aee8f94f8';

/// Online-first `GET /api/me` data (D-01/D-03/D-06).
///
/// On [build], when [isOnlineProvider] is true, a fresh fetch is always
/// attempted first — a populated cache is not consulted on the happy path.
/// If that fetch throws, the cache is checked as a silent fallback (D-03; no
/// distinct error surfaced when a cache hit exists) and only rethrows (as an
/// [AsyncError], driving "Couldn't load profile" + Retry) when there's
/// nothing cached either. When offline, cached data is served directly with
/// zero network calls, or [OfflineNoCacheException] is thrown if nothing has
/// ever been cached (D-06) — recovery from that state is automatic the
/// moment [isOnlineProvider] flips back to true, since [build] re-watches
/// it. This provider has no `_version` guard — there are no local-mutation
/// methods here to race against.
///
/// [refresh] (the UI's pull-to-refresh / refresh-button entry point) dedupes
/// concurrent calls: a second call while one is already in flight reuses the
/// same [Future] rather than firing a second network request.
///
/// Copied from [ProfileData].
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
