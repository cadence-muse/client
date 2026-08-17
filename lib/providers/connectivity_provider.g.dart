// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectivityHash() => r'0d9ff6212f856ef59de11d76b991062a22260032';

/// D-02: single global connectivity signal, seeded via a one-shot
/// `checkConnectivity()` before subscribing to `onConnectivityChanged` — so
/// there is no null/loading gap between app start and the first stream event
/// (UI-SPEC E3/E4). D-03: every event is passed straight through, no
/// debounce.
///
/// Copied from [connectivity].
@ProviderFor(connectivity)
final connectivityProvider =
    AutoDisposeStreamProvider<ConnectivityStatus>.internal(
      connectivity,
      name: r'connectivityProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$connectivityHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectivityRef = AutoDisposeStreamProviderRef<ConnectivityStatus>;
String _$isOnlineHash() => r'7ba0a8c1b984c6d0f03f5731a065cbd565ea5b77';

/// The single value every other file in this phase watches — no other file
/// should call `.when()` on [connectivityProvider] directly. Resolves to
/// `true` only for `AsyncData(ConnectivityStatus.online)`; both
/// `AsyncLoading` and `AsyncError` (including a `connectivity_plus`
/// platform-channel failure) resolve to `false` — fail-safe offline default.
///
/// Copied from [isOnline].
@ProviderFor(isOnline)
final isOnlineProvider = AutoDisposeProvider<bool>.internal(
  isOnline,
  name: r'isOnlineProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isOnlineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsOnlineRef = AutoDisposeProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
