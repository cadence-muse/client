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

  /// Reentrancy guard for [signOut]. A 403 on the best-effort `logout()`
  /// call below triggers [ApiClient.onUnauthorized], which is wired back to
  /// this same `signOut()` — without this guard, that nested call would see
  /// `state.value` still non-null and re-attempt `logout()`, hitting the
  /// same 403 and recursing without a depth bound.
  bool _loggingOut = false;

  Future<void> signIn(String token) async {
    await ref.read(tokenStorageProvider).write(token);
    state = AsyncData(token);
  }

  Future<void> signOut() async {
    if (state.value == null || _loggingOut) return;
    _loggingOut = true;
    try {
      // Best-effort: invalidate the session server-side. Must fire while
      // the token is still attached (before the local clear below), since
      // ApiClient's getToken callback reads this provider's current value.
      // This milestone has no offline mutation queue (see CLAUDE.md), so any
      // failure here (offline, timeout, 403, etc.) is swallowed — local
      // sign-out always completes regardless of network outcome.
      await ref.read(publicApiProvider).logout();
    } catch (_) {
      // Swallow: see comment above.
    } finally {
      _loggingOut = false;
    }
    await ref.read(tokenStorageProvider).delete();
    await ref.read(cacheServiceProvider).clearAll();
    state = const AsyncData(null);
  }
}
