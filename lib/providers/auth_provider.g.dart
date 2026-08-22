// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tokenStorageHash() => r'c55b482201cf22ebfe8999c77ff19ff449cb49e8';

/// See also [tokenStorage].
@ProviderFor(tokenStorage)
final tokenStorageProvider = AutoDisposeProvider<TokenStorage>.internal(
  tokenStorage,
  name: r'tokenStorageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tokenStorageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TokenStorageRef = AutoDisposeProviderRef<TokenStorage>;
String _$apiClientHash() => r'be15acc9197ced75d331e030d5e19087eca0b9be';

/// See also [apiClient].
@ProviderFor(apiClient)
final apiClientProvider = AutoDisposeProvider<ApiClient>.internal(
  apiClient,
  name: r'apiClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$apiClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApiClientRef = AutoDisposeProviderRef<ApiClient>;
String _$publicApiHash() => r'8d8359a98de5e3517ad164d39616f3b27e4a5cc4';

/// See also [publicApi].
@ProviderFor(publicApi)
final publicApiProvider = AutoDisposeProvider<PublicApi>.internal(
  publicApi,
  name: r'publicApiProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$publicApiHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PublicApiRef = AutoDisposeProviderRef<PublicApi>;
String _$authSessionHash() => r'65073b855531000553248db8f60ed11e25a8dd20';

/// Tracks the current auth token and whether the user is signed in.
///
/// The app shell watches this to decide whether to show the login page or
/// the app; [ApiClient] reads the token (via [apiClientProvider]'s
/// `getToken` callback) to authenticate requests and signs the session out
/// when a request comes back with 403 (session no longer valid).
///
/// Copied from [AuthSession].
@ProviderFor(AuthSession)
final authSessionProvider =
    AutoDisposeAsyncNotifierProvider<AuthSession, String?>.internal(
      AuthSession.new,
      name: r'authSessionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authSessionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuthSession = AutoDisposeAsyncNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
