---
phase: 01-foundation-profile-home
reviewed: 2026-08-15T08:32:29Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - lib/api/api_client.dart
  - lib/api/public_api.dart
  - lib/app.dart
  - lib/cache/cache_service.dart
  - lib/features/auth/auth_gate.dart
  - lib/features/auth/login_screen.dart
  - lib/features/home/home_screen.dart
  - lib/features/profile/profile_screen.dart
  - lib/features/settings/settings_screen.dart
  - lib/main.dart
  - lib/navigation/root_scaffold.dart
  - lib/providers/auth_provider.dart
  - lib/providers/homepage_provider.dart
  - lib/providers/profile_provider.dart
  - lib/providers/theme_provider.dart
  - pubspec.yaml
  - test/cache/cache_service_test.dart
  - test/features/home/home_screen_test.dart
  - test/features/profile/profile_screen_test.dart
  - test/providers/auth_provider_test.dart
  - test/providers/homepage_provider_test.dart
  - test/providers/theme_provider_test.dart
  - test/widget_test.dart
findings:
  critical: 1
  warning: 5
  info: 3
  total: 9
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-08-15T08:32:29Z
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Reviewed the Riverpod + Hive walking-skeleton implementation covering auth, API client, cache-first Home/Profile providers, and their screens/tests. Overall architecture is sound (single `ApiClient`, cache-first `AsyncNotifier`s, clean provider overrides in tests), but there is one unguarded type-cast in `HomeScreen` that can crash the app on a malformed/partial API response — inconsistent with the null-safe pattern `ProfileScreen` already uses for the same class of data. There are also several defensive-coding gaps (force-unwrapped API responses, no startup error handling around Hive init, an overly broad cache-read catch) and one widget test (`test/widget_test.dart`) that silently exercises the error path instead of the real data path because it forgets to override `cacheServiceProvider`.

## Critical Issues

### CR-01: Unguarded type casts in HomeScreen can crash on malformed/partial data

**File:** `lib/features/home/home_screen.dart:35-36`
**Issue:** `_buildContent` does `data['username'] as String` and `data['bandsCount'] as int` with no null-safety. If either key is missing or `null` — a genuinely possible state given the data flows through both a live network response *and* a Hive cache round-trip — this throws an uncaught `TypeError` (`type 'Null' is not a subtype of type 'String'`) inside the widget's `build()`. Because the throw happens in the `AsyncValue.when(data: ...)` builder callback rather than inside the async fetch itself, it is **not** caught by the `error:` branch of `.when()` — it propagates as an unhandled Flutter build error (red/gray screen) instead of the graceful "Couldn't load home" + Retry state the app otherwise provides.

This is directly inconsistent with `ProfileScreen._buildContent`, which defends the same shape of data with `profile['username'] as String? ?? ''` and `profile['id'] as String? ?? ''` (`lib/features/profile/profile_screen.dart:40-41`).

**Fix:**
```dart
Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
  final username = data['username'] as String? ?? '';
  final bandsCount = data['bandsCount'] as int? ?? 0;
  ...
```

## Warnings

### WR-01: Missing `mounted` check before `setState` in LoginScreen's error handler

**File:** `lib/features/auth/login_screen.dart:75-76`
**Issue:** The `finally` block correctly guards its `setState` call with `if (mounted)` (line 78), but the `catch (ApiException e)` block right above it does not:
```dart
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);   // no mounted check
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```
If the widget is disposed while `publicApi.register`/`publicApi.login` is still in flight (e.g. the auth state changes out from under it, or the screen is torn down for any other reason), the `await` resumes on a disposed `State`, and this `setState` call throws `FlutterError: setState() called after dispose()` in debug/test builds.

**Fix:**
```dart
} on ApiException catch (e) {
  if (mounted) setState(() => _errorMessage = e.message);
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```

### WR-02: `test/widget_test.dart` doesn't override `cacheServiceProvider`, so it silently tests the error path instead of the real one

**File:** `test/widget_test.dart:71-90`
**Issue:** The test overrides `apiClientProvider` but not `cacheServiceProvider`. `cacheServiceProvider` resolves via `CacheService.instance` (`lib/providers/auth_provider.dart` → `lib/cache/cache_service.dart:84-90`), which throws `StateError('CacheService.initialize() must be called before use.')` unless `CacheService.initialize()` was called first — and this test never calls it (unlike `test/cache/cache_service_test.dart`, which does via `Hive.init`).

That `StateError` is thrown synchronously inside `homepageDataProvider`/`profileDataProvider`'s `build()` (via `ref.watch(cacheServiceProvider)`), gets converted into an `AsyncError`, and both `HomeScreen`/`ProfileScreen` gracefully render their error states because of `.when(error: ...)`. The test's assertions (`find.text('Home')`, `find.text('B.A.T.H.')`) only check the `AppBar` title and an unrelated `BandsScreen` placeholder, so the test passes without ever noticing that Home/Profile data loading is completely broken in this scenario. The test's own comment ("the real apiClientProvider must not attempt a live network call") suggests the author intended to exercise the real fetch path — that intent is currently defeated.

**Fix:**
```dart
overrides: [
  apiClientProvider.overrideWithValue(...),
  cacheServiceProvider.overrideWithValue(CacheService.inMemory()),
],
```

### WR-03: No error handling around Hive/cache initialization at app startup

**File:** `lib/main.dart:8-13`
**Issue:** `Hive.initFlutter()` and `CacheService.initialize()` are awaited with no `try`/`catch`. Any failure here (corrupted box on disk, storage permission issue, etc.) throws out of `main()` before `runApp` is ever called, crashing the app on launch with no recovery path — directly undermining the "still works without signal / a band member can always open the app" value proposition this milestone is built around, since a broken cache now blocks the entire app rather than just disabling offline reads.
**Fix:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
    await CacheService.initialize();
  } catch (e) {
    // fall back to a cache-disabled CacheService, or clear+retry the box,
    // instead of letting main() crash before runApp.
  }
  runApp(const ProviderScope(child: CadenceApp()));
}
```

### WR-04: `_fetchAndCache()` force-unwraps the API response instead of raising a handled error

**File:** `lib/providers/homepage_provider.dart:39-40`, `lib/providers/profile_provider.dart:39-40`
**Issue:** `final homepage = data!;` (and the equivalent `profile = data!;`) assumes `ApiClient.send` never returns `null` for these endpoints. Per `ApiClient.send` (`lib/api/api_client.dart:69`), it *does* return `null` whenever the response body is empty, which is legal for any 2xx status. If the server ever responds `200` with an empty body (e.g. a transient proxy/gateway quirk), this throws a bare `Null check operator used on a null value` instead of surfacing through the existing `ApiException`/`AsyncError` handling that `ProfileScreen`/`HomeScreen` already know how to display.
**Fix:**
```dart
final data = await apiClient.send('GET', '/api/homepage');
if (data == null) {
  throw ApiException(statusCode: 200, code: 'empty_response', message: 'Empty response body');
}
await ref.read(cacheServiceProvider).writeHomepage(data);
return data;
```

### WR-05: Cache read methods swallow all exceptions, not just storage errors

**File:** `lib/cache/cache_service.dart:95-101` (`readProfile`), `lib/cache/cache_service.dart:112-118` (`readHomepage`)
**Issue:** `catch (_) { return null; }` catches every exception type, including bugs (e.g. a bad cast during a future refactor, or a corrupted-but-still-decodable value) — not just Hive I/O failures. This is consistent with the doc comment's intent for *write* failures ("non-critical, keep serving in-memory/network data"), but for *reads* it means a genuine programming error is silently treated as an ordinary cache miss with no logging, making such regressions very hard to notice or diagnose.
**Fix:** At minimum, log the swallowed exception (e.g. via `debugPrint` guarded by `kDebugMode`, or a proper logger once one exists) before returning `null`, so read failures aren't entirely invisible:
```dart
} catch (e, st) {
  if (kDebugMode) debugPrint('CacheService.readProfile failed: $e\n$st');
  return null;
}
```

## Info

### IN-01: Hive round-trip only shallow-converts the top-level map

**File:** `lib/cache/cache_service.dart:23-27`
**Issue:** `_HiveStore.get` does `Map<String, dynamic>.from(raw)`, which only re-types the outer map. Any nested `Map` values coming back from Hive remain loosely typed (`Map<dynamic, dynamic>`) rather than `Map<String, dynamic>`. Not an issue today since `profile`/`homepage` payloads are flat, but the first nested object added to either endpoint's response will silently break any code that does `value['nested'] as Map<String, dynamic>` after a cache read (while working fine on the live-network path, since `jsonDecode` already produces properly typed nested maps). Worth a recursive/deep conversion helper before the schema grows.

### IN-02: Silent background refresh isn't covered by the manual refresh's de-dup guard

**File:** `lib/providers/homepage_provider.dart:31,48-55,60-64` (mirrored in `lib/providers/profile_provider.dart`)
**Issue:** `build()` fires `unawaited(_refresh())` on a cache hit, which is a separate code path from `refresh()`'s `_inFlightRefresh` de-dup guard. If a user taps the visible refresh button in the brief window right after the screen mounts (while the silent background refresh from `build()` is still in flight), two concurrent network requests to the same endpoint will fire instead of one. Low impact (extra request, no correctness issue since both write the same cache key), but worth unifying under a single in-flight guard for consistency with the documented "dedupes concurrent calls" behavior.

### IN-03: Session token interpolated into the Cookie header without sanitization

**File:** `lib/api/api_client.dart:52`
**Issue:** `headers['Cookie'] = 'cadencesession=$token';` interpolates the stored token directly with no validation that it's free of `;`, CR/LF, or other cookie/header-breaking characters. Exploitability today is low — the token is server-issued and read from the app's own secure storage — but there's no defense-in-depth here if secure storage were ever tampered with or a future code path started writing an unvalidated token. Consider a narrow sanity check (e.g. reject/strip control characters) before using the value in a header.

---

_Reviewed: 2026-08-15T08:32:29Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
