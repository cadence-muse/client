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
  onUnauthorized: () =>
      ref.read(authSessionProvider.notifier).signOut(sessionExpired: true),
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

  /// Set by [signOut] when `sessionExpired: true`, and read exactly once by
  /// [consumeSessionExpired] -- see that method's doc comment.
  bool _sessionExpiredFlag = false;

  Future<void> signIn(String token) async {
    await ref.read(tokenStorageProvider).write(token);
    state = AsyncData(token);
  }

  /// D-04: The `'app_locale'` SharedPreferences key (see
  /// `lib/providers/locale_provider.dart`) is a device preference, not
  /// account data — it must survive sign-out. Do not extend this method to
  /// clear it or any other local UI-preference state; only clear
  /// auth-specific keys (token, cache).
  ///
  /// [sessionExpired] distinguishes a forced sign-out (401/403 from
  /// [ApiClient.onUnauthorized]) from a manual one (e.g. Profile screen's
  /// "Log out"). When `true`, it sets [_sessionExpiredFlag] so
  /// [LoginScreen] can show a one-time "Session expired" message via
  /// [consumeSessionExpired] -- a manual sign-out must never set it.
  Future<void> signOut({bool sessionExpired = false}) async {
    if (state.value == null || _loggingOut) return;
    _loggingOut = true;
    try {
      // Best-effort: invalidate the session server-side. Must fire while
      // the token is still attached (before the local clear below), since
      // ApiClient's getToken callback reads this provider's current value.
      // This milestone has no offline mutation queue (see CLAUDE.md), so any
      // failure here (offline, timeout, 401/403, etc.) is swallowed --
      // local sign-out always completes regardless of network outcome.
      await ref.read(publicApiProvider).logout();
    } catch (_) {
      // Swallow: see comment above.
    } finally {
      _loggingOut = false;
    }
    await ref.read(tokenStorageProvider).delete();
    await ref.read(cacheServiceProvider).clearAll();
    if (sessionExpired) _sessionExpiredFlag = true;
    state = const AsyncData(null);
  }

  /// One-time read of [_sessionExpiredFlag], resetting it to `false`.
  /// [LoginScreen] consumes this on mount to decide whether to show a
  /// "Session expired" message -- it only ever returns `true` once per
  /// forced sign-out (`signOut(sessionExpired: true)`), never for a manual
  /// sign-out or a cold start.
  bool consumeSessionExpired() {
    final value = _sessionExpiredFlag;
    _sessionExpiredFlag = false;
    return value;
  }
}
