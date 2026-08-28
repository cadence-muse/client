---
phase: 17-api-contract-sync
reviewed: 2026-08-27T00:00:00Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/api/public_api.dart
  - lib/features/auth/login_screen.dart
  - lib/features/setlists/add_setlist_tracks_dialog.dart
  - lib/features/setlists/setlists_screen.dart
  - lib/features/tracks/tracks_screen.dart
  - lib/generated/app_localizations.dart
  - lib/generated/app_localizations_en.dart
  - lib/generated/app_localizations_ru.dart
  - lib/l10n/app_en.arb
  - lib/l10n/app_ru.arb
  - test/api/public_api_test.dart
  - test/features/auth/login_screen_test.dart
  - test/features/setlists/add_setlist_tracks_dialog_test.dart
  - test/features/setlists/setlists_screen_test.dart
  - test/features/tracks/tracks_screen_test.dart
  - test/providers/setlists_provider_test.dart
  - test/providers/tracks_provider_test.dart
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-08-27
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

`flutter analyze` is clean and the full targeted test suite (118 tests across the
7 listed test files) passes, so surface-level correctness looks fine at first
glance. However, tracing the login-error path against the actual
`lib/api/publicapi.yml` contract — the whole point of an "api-contract-sync"
phase — turns up a real regression: `/api/login` no longer (and per the spec
grep, never did) return `401`, only `400`, but `login_screen.dart` still
branches on `statusCode == 401` to show the friendly "Invalid credentials"
message. That branch is now dead code against the real backend, and the test
that "proves" it (`login_screen_test.dart`) mocks an impossible `401` response,
which means CI is green while the real login-failure UX is broken. This is a
BLOCKER.

Three further issues degrade quality/robustness without being outright broken:
an out-of-order debounced-search race duplicated across three files (new copies
introduced this phase in `tracks_screen.dart`/`setlists_screen.dart`, mirroring
a pre-existing one in `add_setlist_tracks_dialog.dart`), a copy/paste UI-text
mismatch on the new Setlists tab search field, and an inconsistent
error-handling gap in `login_screen.dart` relative to the sibling dialog changed
in the same phase. Two minor Info-level items round out the list.

## Critical Issues

### CR-01: LoginScreen's 401 branch is dead code — the API contract never returns 401 for `/api/login`, so wrong-credential login failures show the wrong message

**File:** `lib/features/auth/login_screen.dart:57-66`
**Issue:**
`_submit()` wraps `publicApi.login(...)` and rewrites the exception only when
`e.statusCode == 401`:

```dart
try {
  final token = await publicApi.login(username: username, password: password);
  await ref.read(authSessionProvider.notifier).signIn(token);
} on ApiException catch (e) {
  if (e.statusCode == 401) {
    throw ApiException(
      statusCode: e.statusCode,
      code: e.code,
      message: l10n.loginInvalidCredentialsError,
    );
  }
  rethrow;
}
```

But `lib/api/publicapi.yml`'s `Login` operation (`/api/login`, lines 39-59) only
declares a `'200'` and a `'400'` response — there is no `401` anywhere in the
spec (`grep -n "401" lib/api/publicapi.yml` returns nothing). `ApiClient.send`
(`lib/api/api_client.dart:60-62`) throws `ApiException.fromResponse(response)`
for any `>= 400` status, so a real wrong-password/wrong-username login attempt
comes back as `400` with a `code` from the 5-value `ErrorCode` enum (most
plausibly `invalid_input`, per `BadRequestResponseBody`/`ErrorCode` in
`publicapi.yml:667-690`) — never `401`. That means:

- The `e.statusCode == 401` branch can never fire against the real backend, so
  `l10n.loginInvalidCredentialsError` is unreachable dead code in production.
- The `code` from the original `400` response survives untouched into the
  outer catch's `e.localizedMessage(l10n, overrides: {'already_exists': ...})`
  (`login_screen.dart:67-73`). If that code is `invalid_input` — one of
  `ApiExceptionLocalization.localizedMessage`'s 5 recognized `ErrorCode`
  switch cases (`lib/api/api_exception.dart:50-63`) — the user instead sees the
  generic `l10n.commonErrorInvalidInput` ("Invalid input.") for a
  wrong-password attempt, not the intended "Invalid credentials" copy.
- `test/features/auth/login_screen_test.dart:125-175` "proves" the 401 path by
  mocking `http.Response('', 401)` directly, which the real API can never send
  per its own contract — the test is green, but it validates a response shape
  that cannot occur in production, giving false confidence that this UX path
  works.

This is exactly the class of bug an "api-contract-sync" phase exists to catch,
and it was missed — the phase's own `17-RESEARCH.md` has zero mentions of
`/api/login` or its error codes.

Compare with the pattern already used one screen over for the analogous
"wrong-secret" case, `changePassword`'s public_api.dart doc comment
(`lib/api/public_api.dart:51-58`, added this same milestone) and
`change_password_screen.dart`'s actual handling:
```dart
overrides: {'invalid_input': l10n.changePasswordIncorrectCurrentError},
```
i.e. branch on `code == 'invalid_input'` via `localizedMessage`'s `overrides`
map, not on a status code the server doesn't send for this operation.

**Fix:** Replace the `statusCode == 401` special case with an `overrides` entry
on the code actually returned for a `400` login failure (confirm the exact
code with the backend team — most likely `invalid_input`), mirroring
`change_password_screen.dart`:
```dart
try {
  final publicApi = ref.read(publicApiProvider);
  if (_mode == _AuthMode.signUp) {
    await publicApi.register(username: username, password: password);
  }
  final token = await publicApi.login(username: username, password: password);
  await ref.read(authSessionProvider.notifier).signIn(token);
} on ApiException catch (e) {
  setState(
    () => _errorMessage = e.localizedMessage(
      l10n,
      overrides: {
        'already_exists': l10n.loginUsernameTakenError,
        'invalid_input': l10n.loginInvalidCredentialsError,
      },
    ),
  );
}
```
and update `login_screen_test.dart`'s two `401`-mocking tests
(lines 125-148, 150-175) to mock `http.Response(jsonEncode({'code': 'invalid_input', 'message': '...'}), 400)`
instead, so the test suite exercises a response shape the real API can
actually send.

## Warnings

### WR-01: Debounced search can display a stale, out-of-order server response

**File:** `lib/features/tracks/tracks_screen.dart:55-75`, `lib/features/setlists/setlists_screen.dart:62-81`, `lib/features/setlists/add_setlist_tracks_dialog.dart:76-91`
**Issue:** All three `_onSearchChanged` implementations cancel the previous
*debounce timer* on every keystroke, but never cancel or sequence the
*in-flight network request* the timer eventually fires. If a user pauses long
enough to fire request A (searchQuery `"a"`), then resumes typing and pauses
again to fire request B (searchQuery `"ab"`) before A's response arrives, and
A is slower than B (plausible on a flaky connection), A's response lands after
B's and silently overwrites the fresher, correct state:
```dart
final results = await ref.read(publicApiProvider).listUserTracks(...);
if (!mounted) return;
setState(() => _serverSearchResults = results);   // no check that this
                                                    // response is still current
```
The user is left looking at results for a query they've already changed away
from, with no visual indication anything is wrong. Two of the three occurrences
(`tracks_screen.dart`, `setlists_screen.dart`) are new files/features added in
this phase (`git log` shows both introduced by `81847d9`/`a4a3a8b`, "feat(17-01)"),
so this is a duplicated, not merely inherited, gap.
**Fix:** Capture the query (or a monotonic request token) at the moment the
debounced request is issued, and only apply the result if it's still current:
```dart
_debounceTimer = Timer(const Duration(milliseconds: 300), () async {
  if (!mounted) return;
  final requestQuery = _searchQuery;
  try {
    final results = await ref.read(publicApiProvider).listUserTracks(
      bandIdFilter: ref.read(selectedBandIdFilterProvider),
      searchQuery: requestQuery,
    );
    if (!mounted || requestQuery != _searchQuery) return;
    setState(() => _serverSearchResults = results);
  } catch (_) {}
});
```

### WR-02: SetlistsScreen's search field reuses Tracks-tab copy that doesn't match what it actually searches

**File:** `lib/features/setlists/setlists_screen.dart:124`
**Issue:** The Setlists tab's `TextField` uses
`hintText: l10n.addSetlistTracksSearchHint`, whose English string is "Search by
title or artist" (`lib/l10n/app_en.arb:254`). But `_setlistMatchesSearchQuery`
(`setlists_screen.dart:23-27`) and the server-side `searchQuery` param for
`ListUserSetlists` only match against `setlist['name']` — setlists have no
"artist" field at all (`SetlistListItem`/`BandSetlist` schemas). A user reading
the hint on the Setlists tab is told to search by "title or artist," neither of
which is what the field does. `17-UI-SPEC.md:110` does direct reuse of this key
for both tabs, but that's a spec oversight, not a deliberate UX decision — the
phase otherwise added a setlist-specific empty-results string
(`commonNoSetlistSearchResults`, distinct from the tracks-tab
`commonNoSearchResults`) precisely because the two domains needed different
copy.
**Fix:** Add a setlist-specific hint key (e.g. `setlistsSearchHint`: "Search by
name") and use it in `setlists_screen.dart` instead of reusing
`addSetlistTracksSearchHint`.

### WR-03: LoginScreen's `_submit()` has no fallback for non-`ApiException` failures, unlike the sibling code changed in this same phase

**File:** `lib/features/auth/login_screen.dart:46-76`
**Issue:** `_submit()`'s outer `try` only has `on ApiException catch (e)`. A raw
network failure during `register()`/`login()` (timeout, `SocketException`, DNS
failure, malformed JSON from a proxy, etc.) is not an `ApiException` and
propagates unhandled out of the `async` method. The `finally` block still resets
`_isSubmitting`, so the UI doesn't visibly hang, but the user gets zero
indication of what went wrong — no error text is ever set. Contrast with
`add_setlist_tracks_dialog.dart`'s `_submit()` (touched in this same phase),
which explicitly adds:
```dart
} catch (_) {
  if (!mounted) return;
  final l10n = AppLocalizations.of(context)!;
  setState(() => _errorMessage = l10n.addSetlistTracksFailedError);
}
```
i.e. the established pattern elsewhere in this phase's own diff is to always
have a generic fallback; `login_screen.dart` is the outlier.
**Fix:** Add a generic `catch (_)` branch to `login_screen.dart._submit()`
mirroring `add_setlist_tracks_dialog.dart`, e.g. setting `_errorMessage` to
`l10n.commonSomethingWentWrong`.

## Info

### IN-01: `tracks_screen.dart` has an un-formatted line (dartfmt violation)

**File:** `lib/features/tracks/tracks_screen.dart:14`
**Issue:** `dart format --set-exit-if-changed` flags this file — the import on
line 14 exceeds the wrap width dartfmt would apply:
```dart
import '../setlists/add_setlist_tracks_dialog.dart' show trackMatchesSearchQuery;
```
Per `CLAUDE.md`'s documented convention, "Dart's built-in formatter (dartfmt)
is the standard." `flutter analyze`/CI won't fail on this (the `validate.yml`
workflow doesn't run `dart format --set-exit-if-changed`), but it's a real
deviation from project style.
**Fix:** Run `dart format lib/features/tracks/tracks_screen.dart`.

### IN-02: Duplicated `effectiveSearchQuery` normalization in `public_api.dart`

**File:** `lib/api/public_api.dart:280-297`, `443-460`
**Issue:** `listUserTracks` and `listUserSetlists` each independently
re-implement the identical "treat null/empty searchQuery as absent" logic:
```dart
final effectiveSearchQuery = (searchQuery != null && searchQuery.isNotEmpty)
    ? searchQuery
    : null;
```
`listBandTracks` (lines 173-185) does the equivalent check inline instead. Not
a bug, but a small, easily-drifting duplication across three call sites that a
private helper would eliminate.
**Fix:** Extract a small `String? _normalizedSearchQuery(String? q) => (q == null || q.isEmpty) ? null : q;` and reuse it in all three methods.

---

_Reviewed: 2026-08-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
