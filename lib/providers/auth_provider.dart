import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_client.dart';
import '../api/public_api.dart';
import '../api/token_storage.dart';
import '../cache/cache_service.dart';
import '../config/app_config.dart';

part 'auth_provider.g.dart';

@riverpod
TokenStorage tokenStorage(TokenStorageRef ref) => TokenStorage();

@riverpod
ApiClient apiClient(ApiClientRef ref) => ApiClient(
  baseUrl: AppConfig.apiBaseUrl,
  getToken: () => ref.read(authSessionProvider).value,
  onUnauthorized: () => ref.read(authSessionProvider.notifier).signOut(),
);

@riverpod
PublicApi publicApi(PublicApiRef ref) =>
    PublicApi(ref.watch(apiClientProvider));

/// Tracks the current auth token and whether the user is signed in.
///
/// The app shell watches this to decide whether to show the login page or
/// the app; [ApiClient] reads the token (via [apiClientProvider]'s
/// `getToken` callback) to authenticate requests and signs the session out
/// when a request comes back with 403 (session no longer valid).
@riverpod
class AuthSession extends _$AuthSession {
  @override
  Future<String?> build() => ref.watch(tokenStorageProvider).read();

  Future<void> signIn(String token) async {
    await ref.read(tokenStorageProvider).write(token);
    state = AsyncData(token);
  }

  Future<void> signOut() async {
    if (state.value == null) return;
    await ref.read(tokenStorageProvider).delete();
    await ref.read(cacheServiceProvider).clearAll();
    state = const AsyncData(null);
  }
}
