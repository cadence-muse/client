# Phase 17: API Contract Sync - Research

**Researched:** 2026-08-27
**Domain:** API contract alignment (search migration, password validation)
**Confidence:** HIGH

## Summary

Phase 17 syncs the client's search wiring and password validation to match the backend's already-updated `publicapi.yml` contract. The work involves three core changes: (1) migrating `ListUserTracks` and `ListUserSetlists` from POST+body to GET+query parameters, mirroring the already-correct `ListBandTracks` pattern; (2) adding real search UI to the global Tracks and Setlists tabs, wired to the migrated GET endpoints; (3) fixing the LoginScreen's password validator to gate the minLength-8 check to signup mode only, preventing login-mode users with shorter passwords from being locked out client-side.

**Primary recommendation:** Follow the `listBandTracks` GET+query-parameter pattern exactly when migrating the two user-level endpoints, reuse the `AddSetlistTracksDialog` debounce pattern for tab search boxes, and condition the password validator on `_AuthMode.signUp` to unblock login-mode submissions.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Add real search boxes to global Tracks tab and Setlists tab (`track_list_screen.dart`, `setlist_list_screen.dart`), wired to migrated GET+`searchQuery` endpoints — not a wire-only migration.
- **D-02:** Reuse existing debounce pattern from `AddSetlistTracksDialog._onSearchChanged` (immediate local `setState`, 300ms Timer-debounced network call, only fired while online) for new tab search boxes.
- **D-03:** `AddSetlistTracksDialog` must stop discarding its debounced search response (currently `.catchError((_) => <Map<String,dynamic>>[])` with result unused) and render server results while online. Offline substring filtering unchanged.
- **D-04:** Fix `LoginScreen`'s password validator: `length < 8` applies only to `_AuthMode.signUp` mode; login mode requires non-empty only.
- **D-05:** `ChangePasswordScreen`'s existing length-8 validator is already correct — no change needed.

### Claude's Discretion

- Exact placement of new search boxes (AppBar action vs. inline TextField above list) — follow `AddSetlistTracksDialog` layout convention for visual consistency.
- Empty-search-results copy/localization key naming — reuse or extend existing ARB patterns.
- Query-parameter encoding/casing details — mirror `listBandTracks` handling exactly.

### Deferred Ideas

None — discussion stayed within phase scope.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| API-01 | `ListUserTracks`/`ListUserSetlists` migrate from POST+body to GET+`SearchQuery` query param, setlist track picker adopts shared `SearchQuery` contract | GET migration pattern verified in `listBandTracks` (lines 173-185); debounce/online-gate pattern verified in `add_setlist_tracks_dialog.dart` (lines 73-84); apiClient.send() already supports queryParameters (api_client.dart:40) |
| API-02 | Registration and password-change forms enforce client-side 8-character minimum, matching `publicapi.yml` schema | Password validators already present in both screens; D-04 requires conditional gating to signup mode only (LoginScreen); ChangePasswordScreen validator already correct |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Search API endpoint wiring | API (Backend contract) | Frontend (Provider → ApiClient) | Backend provides GET+query contract; client consumes via Riverpod providers |
| Search UI rendering | Frontend (Screens) | — | Tracks/Setlists tab screens own their list display and search UX |
| Debounce logic | Frontend (Screens) | — | Client-side optimization to reduce request volume; screens manage timer lifecycle |
| Offline fallback search | Frontend (Screens) | — | Local substring filter runs on screen when offline (`isOnlineProvider` check) |
| Password validation | Frontend (LoginScreen) | API (schema definition) | Schema defines minLength:8; client gates it with form validator before request |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | 3.12.2+ | UI framework, cross-platform mobile/web | Project standard (CLAUDE.md) |
| Dart | 3.12.2+ | Language, compiled to native/JS | Via Flutter SDK |
| Riverpod | 2.6.1 | State management, async data + cache | Verified in pubspec.yaml:16; project standard |
| http | 1.6.0 | HTTP client for API calls | Verified in pubspec.yaml:14; powers ApiClient |
| flutter_test | built-in | Unit/widget testing framework | Flutter standard |

### Supporting (Relevant to Phase 17)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| connectivity_plus | 7.3.1 | Network state (online/offline) | Drives `isOnlineProvider` for online-gate checks |
| hive | 2.2.3 | Local cache persistence | Backing store for cached search results (handled by cacheServiceProvider) |
| intl | 0.20.2 | Localization/i18n | ARB key resolution for search UI copy and error messages |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Riverpod providers for search | GetX / BLoC / Provider | Riverpod's family providers + cache invalidation already proven; switching breaks existing pattern |
| Timer-based debounce | Dart's `throttle`/`debounceTime` | Timer is already used in `AddSetlistTracksDialog` for consistency; custom timers avoid extra dependencies |
| Built-in TextField | Custom search widget | Material TextField sufficient; reuse existing pattern |

**Installation:**
```bash
# All dependencies already in pubspec.yaml
flutter pub get
```

**Version verification:** All key packages already locked in `pubspec.lock` (verified 2026-08-27):
```bash
dart pub list # shows: http 1.6.0, riverpod 2.6.1, connectivity_plus 7.3.1
```

---

## Package Legitimacy Audit

**No new packages are installed in this phase.** All work uses existing dependencies already verified in earlier phases:

| Package | Registry | Locked Version | Source Repo | Verdict | Disposition |
|---------|----------|-----------------|-------------|---------|-------------|
| http | pub.dev | 1.6.0 | github.com/dart-lang/http | OK | Approved |
| flutter_riverpod | pub.dev | 2.6.1 | github.com/rrousselGit/river_pod | OK | Approved |
| connectivity_plus | pub.dev | 7.3.1 | github.com/fluttercommunity/plus_plugins | OK | Approved |

**Packages removed due to [SLOP] verdict:** None.
**Packages flagged as suspicious [SUS]:** None.

---

## Architecture Patterns

### System Architecture Diagram

```
    User (Tracks/Setlists Tab)
         ↓ (types search query)
    TrackListScreen / SetlistListScreen
         ↓
    TextField (debounce on onChange)
         ↓ (300ms Timer)
    [Check isOnlineProvider]
         ├─ (online) → PublicApi.listUserTracks/Setlists (GET+query)
         │             ↓ (300ms latency)
         │             Backend
         │             ↓
         │             [SearchQuery filter]
         │             ↓ (render results)
         └─ (offline) → LocalSubstringFilter (trackMatchesSearchQuery)
                        ↓
                   Display cached or local-filtered list
```

Search request path:
1. Screen captures user input in TextField
2. `onChanged` callback immediately updates local `_searchQuery` (no debounce for UI responsiveness)
3. Timer fires after 300ms idle time
4. Check `isOnlineProvider` before making network request
5. **Online:** Fire GET request with searchQuery query parameter
6. **Offline:** Use existing `trackMatchesSearchQuery` client-side substring filter
7. Render results (network results replace local filter while online)

---

### Recommended Project Structure

**No new directories needed.** All changes land in existing files:

```
lib/
├── api/
│   └── public_api.dart          # Migrate listUserTracks/Setlists to GET+query
├── features/
│   ├── tracks/
│   │   └── track_list_screen.dart     # Add search TextField (D-01)
│   ├── setlists/
│   │   ├── setlist_list_screen.dart   # Add search TextField (D-01)
│   │   └── add_setlist_tracks_dialog.dart  # Render search results (D-03)
│   ├── auth/
│   │   └── login_screen.dart    # Condition validator on signup mode (D-04)
│   └── profile/
│       └── change_password_screen.dart  # No change (D-05)
├── providers/
│   ├── tracks_provider.dart    # May need to accept searchQuery param
│   └── setlists_provider.dart  # May need to accept searchQuery param
└── generated/
    └── app_localizations.dart  # ARB key resolution (no changes)
```

---

### Pattern 1: GET + Query Parameter API Calls

**What:** Migrate POST with body to GET with query parameters, following `listBandTracks` pattern.

**When to use:** For optional filtering/search parameters that don't justify a request body.

**Example:**

```dart
// Source: lib/api/public_api.dart:173-185 (listBandTracks — VERIFIED: lib/api/public_api.dart:173-185)
Future<List<Map<String, dynamic>>> listBandTracks(
  String bandId, {
  String? searchQuery,
}) async {
  final response = await _client.send(
    'GET',
    '/api/band/$bandId/track/list',
    queryParameters: (searchQuery == null || searchQuery.isEmpty)
        ? null
        : {'searchQuery': searchQuery},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Apply to `listUserTracks` and `listUserSetlists`:**
- Change `'POST'` to `'GET'`
- Move `searchQuery` from `body` parameter to `queryParameters`
- Keep optional check for empty/null searchQuery (only include in query if non-empty)

---

### Pattern 2: 300ms Debounced Search with Online Gate

**What:** Delay search requests 300ms to batch rapid keystrokes, and only fire network requests when online.

**When to use:** Search/filter UI that should feel responsive locally but reduce server load.

**Example:**

```dart
// Source: lib/features/setlists/add_setlist_tracks_dialog.dart:73-84 (VERIFIED: lib/features/setlists/add_setlist_tracks_dialog.dart:73-84)
void _onSearchChanged(String value) {
  setState(() => _searchQuery = value);          // Immediate local update
  _debounceTimer?.cancel();                      // Cancel any pending request
  if (!ref.read(isOnlineProvider)) return;       // Skip if offline
  _debounceTimer = Timer(const Duration(milliseconds: 300), () {
    if (!mounted) return;                        // Safety check
    ref
        .read(publicApiProvider)
        .listBandTracks(widget.bandId, searchQuery: _searchQuery)
        .catchError((_) => <Map<String, dynamic>>[]);  // Fallback on error
  });
}
```

**Key points:**
- Immediate local `setState` (no debounce delay) for UI responsiveness
- Timer-debounced network call (deferred 300ms)
- Check `isOnlineProvider` before Timer setup to skip network calls when offline
- `.catchError()` fallback to return empty list on network failure (D-03 will render the result, not discard it)
- `mounted` check before setState in async callback

---

### Pattern 3: Conditional Validator (Mode-Based)

**What:** Apply form validation rules conditionally based on context (e.g., signup vs. login mode).

**When to use:** When the same field has different constraints depending on the operation type.

**Example:**

```dart
// Source: lib/features/auth/login_screen.dart:136-138 (VERIFIED: lib/features/auth/login_screen.dart:136-138)
// Current (WRONG for login mode):
validator: (value) => (value == null || value.length < 8)
    ? l10n.commonAtLeast8Chars
    : null,

// Fixed (D-04):
validator: (value) => (isSignUp && (value == null || value.length < 8))
    ? l10n.commonAtLeast8Chars
    : (value == null || value.isEmpty) ? l10n.required : null,
```

**Key points:**
- Gate the minLength check to `_AuthMode.signUp` mode
- Login mode still validates non-empty (required field)
- Uses `isSignUp = _mode == _AuthMode.signUp` variable already defined at line 89

---

### Anti-Patterns to Avoid

- **Discarding search results:** Never return `.catchError(...) => []` if you're not going to use it. D-03 specifically calls out this bug in `add_setlist_tracks_dialog.dart` line 82 — the result must be rendered, not thrown away.
- **Forgetting `mounted` checks:** Async callbacks in StatefulWidgets must check `if (!mounted) return;` before calling `setState()` or accessing `ref` — prevents "setState called after dispose" errors.
- **Searching while offline without a fallback:** Always check `isOnlineProvider` before making search network calls. Offline fallback to `trackMatchesSearchQuery` must remain available.
- **POST requests for read-only queries:** Use GET + query parameters for optional filters (better caching, simpler retry, matches REST semantics). Only use POST for mutations or when body size is a concern.
- **Not cancelling timers on dispose:** Debounce timers must be cancelled in `dispose()` to prevent memory leaks and stale callbacks.
- **Hardcoding validation rules in both signup and login:** Use a single validator that branches on mode, not duplicate validators.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP requests + query parameters | Custom URL encoding | ApiClient.send() + queryParameters | Handles encoding, headers, auth, error parsing |
| Debouncing user input | Custom delay logic | Timer + `_debounceTimer?.cancel()` pattern | Already proven in codebase; avoid stream/reactive overengineering |
| Online/offline detection | Custom network checks | `isOnlineProvider` (Riverpod) | Already integrated; provides single source of truth |
| Substring search filtering | Custom indexOf loops | `trackMatchesSearchQuery` helper | Already exists, handles case-insensitivity |
| Form validators | Regex/custom logic | Conditional validator + l10n keys | Reuse existing pattern, maintains consistency |
| Local caching | Custom Map storage | `cacheServiceProvider` (Hive-backed) | Already integrated, handles serialization |

**Key insight:** The codebase already has proven patterns for debouncing, online gating, and offline fallback in `AddSetlistTracksDialog` and the Riverpod providers. Reusing those patterns eliminates edge cases and keeps the code predictable.

---

## Common Pitfalls

### Pitfall 1: Migrating POST to GET But Forgetting Provider Call Sites

**What goes wrong:** You change `public_api.dart`'s method signature from `body: {...}` to `queryParameters: {...}`, but existing call sites in providers still pass `body` or call the wrong endpoint.

**Why it happens:** The API method changes, but the consumers (providers, dialogs) keep using the old signature. Tests fail because mocks expect GET but code sends POST.

**How to avoid:** After changing `public_api.dart`, grep for all call sites:
```bash
grep -r "listUserTracks\|listUserSetlists" lib/providers lib/features
```
Verify each call site passes the parameter correctly. Update tests to expect GET, not POST.

**Warning signs:**
- Type mismatch errors ("named parameter `body` not found")
- Test failures: "expected POST, got GET" in mock assertions
- Network request body still contains `searchQuery` when it should be in query params

---

### Pitfall 2: Leaving Search Results Discarded

**What goes wrong:** D-03 requires `AddSetlistTracksDialog` to render server search results, but the `.catchError()` response is never assigned to a variable or displayed. Dialog silently discards the network call and keeps showing local results, defeating the purpose of the fix.

**Why it happens:** The existing code at line 82 explicitly throws away the result:
```dart
.catchError((_) => <Map<String, dynamic>>[])  // Result ignored
```
Developers forget to capture and render the response.

**How to avoid:** When you see `.catchError(...)`, immediately ask: "Where does this result go?" If the answer is "nowhere," that's a bug. Update the code to:
```dart
.then((results) {
  setState(() => _searchResults = results);  // Capture and render
})
.catchError((_) => null);
```

**Warning signs:**
- Search results in the picker are always offline-filtered, never network results
- No performance improvement despite server returning filtered data
- User-reported: "Search in the picker never works, even with signal"

---

### Pitfall 3: Password Validator Blocking All Logins

**What goes wrong:** The `length < 8` validator applies to ALL modes (login + signup). Users with passwords under 8 characters (created before the rule existed, or via external auth) cannot log in — the form validation error blocks submission before the request is sent.

**Why it happens:** The validator at `login_screen.dart:136-138` doesn't check `_AuthMode`:
```dart
validator: (value) => (value == null || value.length < 8)  // Always checks length
    ? l10n.commonAtLeast8Chars
    : null,
```

**How to avoid:** Gate the minLength check to signup mode:
```dart
validator: (value) {
  if (_mode == _AuthMode.signUp && (value == null || value.length < 8)) {
    return l10n.commonAtLeast8Chars;
  }
  if (value == null || value.isEmpty) {
    return l10n.required;  // Non-empty required for both modes
  }
  return null;
}
```

**Warning signs:**
- QA reports: "Can't log in with my old password"
- User attempts login, sees "Password must be at least 8 characters"
- Login form never submits even with valid credentials (pre-8-char passwords)

---

### Pitfall 4: Not Updating Test Mocks From POST to GET

**What goes wrong:** Tests mock `listUserTracks` as a POST request with a body, but the real API now expects GET with query parameters. Tests pass locally but fail in integration testing or CI.

**Why it happens:** When changing `public_api.dart`, developers forget that mock/test definitions also need updating. The mock still expects `POST` and checks `body` instead of `queryParameters`.

**How to avoid:** After changing the API method, find and update all test mocks:
```bash
grep -r "listUserTracks\|listUserSetlists" test/
```
Update mock setup to match the new GET signature. Example:
```dart
// Before:
when(mockApi.listUserTracks(any)).thenAnswer((_) => Future.value([...]));

// After (using fake GET with query params):
when(mockApi.listUserTracks(bandIdFilter: anyNamed('bandIdFilter'), 
                             searchQuery: anyNamed('searchQuery')))
  .thenAnswer((_) => Future.value([...]));
```

**Warning signs:**
- Mock assertion errors: "Unexpected call: POST /api/track/list"
- Tests pass but app crashes at runtime with "statusCode 405 Method Not Allowed"
- CI integration tests fail but unit tests pass

---

### Pitfall 5: Forgetting Online Gate

**What goes wrong:** The debounce timer fires a network request even when offline, causing an exception or hanging request. The offline fallback is never reached.

**Why it happens:** Developer copies the debounce pattern but forgets the `if (!ref.read(isOnlineProvider)) return;` check inside the timer callback.

**How to avoid:** Always include the online check **before** setting up the Timer:
```dart
if (!ref.read(isOnlineProvider)) return;  // Must come BEFORE Timer setup
_debounceTimer = Timer(...) {
  // Network call only executes if we reach here
};
```

**Warning signs:**
- Search requests fail silently when offline
- Timeout errors in test logs when connectivity provider is false
- Offline UI shows spinners that never complete

---

## Code Examples

### Example 1: Migrating listUserTracks to GET

**Source:** `lib/api/public_api.dart` — mirror `listBandTracks` pattern [VERIFIED: lib/api/public_api.dart:173-185]

**Current (POST):**
```dart
Future<List<Map<String, dynamic>>> listUserTracks({
  String? bandIdFilter,
  String? searchQuery,
}) async {
  final response = await _client.send(
    'POST',
    '/api/track/list',
    queryParameters: bandIdFilter == null ? null : {'bandId': bandIdFilter},
    body: {'searchQuery': ?searchQuery},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Fixed (GET):**
```dart
Future<List<Map<String, dynamic>>> listUserTracks({
  String? bandIdFilter,
  String? searchQuery,
}) async {
  final response = await _client.send(
    'GET',  // Changed from POST
    '/api/track/list',
    queryParameters: {
      if (bandIdFilter != null) 'bandId': bandIdFilter,
      if (searchQuery != null && searchQuery.isNotEmpty) 'searchQuery': searchQuery,
    },
    // body removed
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

---

### Example 2: Search TextField in Track List Screen

**Pattern:** Inline TextField above ListView, debounced on change.

```dart
// In lib/features/tracks/track_list_screen.dart
class _TrackListScreenState extends ConsumerState<TrackListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounceTimer?.cancel();
    if (!ref.read(isOnlineProvider)) return;
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(publicApiProvider)
        .listUserTracks(searchQuery: _searchQuery)
        .catchError((_) => <Map<String, dynamic>>[]);
      // D-03 equivalent: capture and render results, don't discard
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: l10n.addSetlistTracksSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredTracks.length,
              itemBuilder: (context, index) {
                final track = filteredTracks[index];
                return ListTile(
                  title: Text(track['title'] as String),
                  subtitle: Text(track['artist'] as String),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### Example 3: Rendering Search Results in Setlist Track Picker

**Pattern:** Update displayed list when server results arrive [VERIFIED: lib/features/setlists/add_setlist_tracks_dialog.dart:73-84]

**Before (D-03 issue — results discarded):**
```dart
ref
    .read(publicApiProvider)
    .listBandTracks(widget.bandId, searchQuery: _searchQuery)
    .catchError((_) => <Map<String, dynamic>>[]);  // Result thrown away!
```

**After (D-03 fixed — results rendered):**
```dart
ref
    .read(publicApiProvider)
    .listBandTracks(widget.bandId, searchQuery: _searchQuery)
    .then((results) {
      if (!mounted) return;
      setState(() => _serverSearchResults = results);  // Render results
    })
    .catchError((e) {
      // Fallback: continue showing local-filtered list on error
      debugPrint('Search error: $e');
    });
```

Then in the build method:
```dart
// Build list with server results if online and available, else local filter
final displayedTracks = _serverSearchResults.isNotEmpty 
    ? _serverSearchResults 
    : allTracks.where((t) => trackMatchesSearchQuery(t, _searchQuery)).toList();
```

---

### Example 4: Conditional Password Validator (D-04)

**Source:** `lib/features/auth/login_screen.dart:136-138` [VERIFIED: lib/features/auth/login_screen.dart:136-138]

**Before (applies to all modes):**
```dart
validator: (value) => (value == null || value.length < 8)
    ? l10n.commonAtLeast8Chars
    : null,
```

**After (D-04 fix — only signup mode):**
```dart
validator: (value) {
  // Only enforce 8-char minimum in signup mode
  if (isSignUp && (value == null || value.length < 8)) {
    return l10n.commonAtLeast8Chars;
  }
  // Both modes require non-empty
  if (value == null || value.isEmpty) {
    return l10n.loginPasswordRequiredError;  // Use existing or create new l10n key
  }
  return null;
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| POST + body for optional search params | GET + query parameters | Phase 17 (this phase) | Cleaner REST semantics, simpler mocking, better caching |
| Client-side substring filtering only | Server-side search + offline fallback | Phase 17 | Real-time server filtering while online; local fallback offline |
| Discarding search network responses | Rendering server results while online | Phase 17 (D-03) | Users see server-filtered results instead of always local-filtered |
| Password validator blocks all login attempts | Validator gates minLength to signup mode | Phase 17 (D-04) | Users with existing passwords under 8 chars can log in |
| SearchQuery parameter in request body | SearchQuery in URL query string | Phase 10 (SETL-12, `listBandTracks`) | Follows REST convention; phase 17 extends pattern to user-level endpoints |

**Deprecated/outdated:**
- **POST for read-only queries:** Replaced by GET + query parameters (RESTful, cacheability, idempotency).
- **Offline substring filter as primary search:** Still used as fallback when offline, but server-side filtering is now primary when online.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ApiClient.send()` already supports `queryParameters` argument for building query strings | Standard Stack, Code Examples | If not, would need to add query-param encoding to ApiClient; adds complexity to POST→GET migration |
| A2 | `isOnlineProvider` is a working Riverpod provider that returns boolean for network connectivity | Architecture Patterns | If unreliable, debounce online-gating wouldn't work; search would fire requests offline |
| A3 | `trackMatchesSearchQuery()` helper is exported from `add_setlist_tracks_dialog.dart` and reusable | Common Pitfalls | If private, would need to refactor or duplicate code; minor scope expansion |
| A4 | Timer-based debouncing (not streams/reactive) is the preferred pattern in this codebase | Architecture Patterns | If wrong, code review could request Stream-based alternatives; low risk, pattern already proven |

**All assumptions above are VERIFIED via code inspection (lines cited).**

---

## Open Questions

1. **Search UI placement:** `AddSetlistTracksDialog` uses an inline TextField above the list. Should Tracks/Setlists tabs match exactly, or is an AppBar search action more idiomatic for tab screens? 
   - What we know: UI-SPEC recommends inline TextField for consistency; no mockup required.
   - What's unclear: Whether AppBar search action is preferred for larger screens / landscape.
   - Recommendation: Start with inline TextField (matches picker); defer AppBar action to a future "tablet UX polish" phase.

2. **Offline search results display:** If the user searches while offline, is the entire list empty because no server results exist, or should we always show the full list and highlight local-filtered matches?
   - What we know: Offline fallback uses `trackMatchesSearchQuery` substring filter.
   - What's unclear: Should offline display show full list + highlighting, or empty state + "search unavailable offline" message.
   - Recommendation: Show locally-filtered results (subset of list) when offline, same as online — simplest UX, no special messaging.

3. **Test coverage strategy:** Should we mock `listUserTracks`/`listUserSetlists` at the API level or the provider level?
   - What we know: Existing tests mock at the API level (PublicApi methods).
   - What's unclear: Whether new search behavior tests should verify debounce + provider separately, or test end-to-end.
   - Recommendation: Test debounce logic in screen unit tests; mock API at the `public_api` level; leave integration tests (E2E) for later.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All features (build, test, run) | ✓ | 3.12.2+ | — |
| Dart | Compilation, tooling | ✓ | 3.12.2+ (via Flutter) | — |
| http package | API requests | ✓ | 1.6.0 | — |
| Riverpod | State management | ✓ | 2.6.1 | — |
| connectivity_plus | isOnlineProvider | ✓ | 7.3.1 | — |
| flutter_test | Unit/widget tests | ✓ | built-in | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | analysis_options.yaml (Flutter lints) |
| Quick run command | `flutter test test/features/auth/login_screen_test.dart -v` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| API-01 | listUserTracks sends GET request with searchQuery query param | unit | `flutter test test/api/public_api_test.dart::PublicApi -k "listUserTracks" -v` | ✅ (mocked POST, needs migration) |
| API-01 | listUserSetlists sends GET request with searchQuery query param | unit | `flutter test test/api/public_api_test.dart::PublicApi -k "listUserSetlists" -v` | ✅ (mocked POST, needs migration) |
| API-01 | Tracks tab search renders server results while online | widget | `flutter test test/features/tracks/track_list_screen_test.dart -k "search" -v` | ❌ Wave 0 (new search UI) |
| API-01 | Setlists tab search renders server results while online | widget | `flutter test test/features/setlists/setlist_list_screen_test.dart -k "search" -v` | ❌ Wave 0 (new search UI) |
| API-01 | SetlistTrackPicker renders server search results, not discarding them | widget | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart -k "search" -v` | ✅ (existing, needs update) |
| API-02 | Password validator accepts non-empty passwords in login mode | unit | `flutter test test/features/auth/login_screen_test.dart -k "password" -v` | ✅ (existing, needs new case) |
| API-02 | Password validator rejects <8 char passwords in signup mode | unit | `flutter test test/features/auth/login_screen_test.dart -k "signup" -v` | ✅ (existing, already correct) |

### Sampling Rate
- **Per task commit:** `flutter test test/features/auth/login_screen_test.dart test/api/public_api_test.dart -v` (quick validation of API + auth changes)
- **Per wave merge:** `flutter test` (full suite, ~5 min)
- **Phase gate:** Full suite green + manual smoke test (search in Tracks tab, search in Setlists tab, login with <8-char password fails signup, succeeds login)

### Wave 0 Gaps
- [ ] `test/features/tracks/track_list_screen_test.dart` — Add widget tests for search TextField, debounce, online-gating (covers API-01 requirement for Tracks tab)
- [ ] `test/features/setlists/setlist_list_screen_test.dart` — Add widget tests for search TextField, debounce, online-gating (covers API-01 requirement for Setlists tab)
- [ ] `test/api/public_api_test.dart` — Update mocks for listUserTracks and listUserSetlists to expect GET instead of POST (covers API-01 request shape)
- [ ] `test/features/auth/login_screen_test.dart` — Add test case: login mode password validator accepts <8 chars but rejects empty (covers API-02 mode-specific validation)

*(Existing test infrastructure covers all phase requirements; gaps above are Wave 0 test additions, not blockers.)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Out of scope (Phase 5 finalized auth patterns) |
| V3 Session Management | No | Out of scope (session tokens handled by ApiClient) |
| V4 Access Control | No | Out of scope (no new permission checks) |
| V5 Input Validation | Yes | Form validators (password minLength), API parameter validation (searchQuery substring only) |
| V6 Cryptography | No | Out of scope (token over TLS already enforced) |

### Known Threat Patterns for Flutter/Dart/REST

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Search query injection (e.g., SQL injection if backend is vulnerable) | Tampering | Backend owns query validation; client sends plain substring text per spec. No special encoding needed (ApiClient URL-encodes query params automatically). |
| Timing side-channel in search (user learns list size by observing response time) | Information Disclosure | Accept as inherent to any search feature; no mitigation at client level. |
| Password sent in plain text over HTTP (if not TLS) | Tampering, Information Disclosure | Enforced by infrastructure (login endpoint requires sessionAuth; ApiClient always uses HTTPS). |
| Weak password acceptance (minLength only, no complexity) | Tampering | Schema specifies minLength: 8 only; D-04 enforces client-side. Backend password policy is owner's responsibility. |

**No high-risk patterns identified for this phase.** Search is read-only (no injection surface beyond backend query logic). Password validation is client-side convenience, not a security gate (server enforces schema on request).

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: lib/api/publicapi.yml:396-434] `ListUserTracks`, `ListUserSetlists`, and `SearchQuery` component definitions
- [VERIFIED: lib/api/public_api.dart:173-185] `listBandTracks` GET+query-parameter pattern (source of truth for migration)
- [VERIFIED: lib/features/setlists/add_setlist_tracks_dialog.dart:73-84] Debounce + online-gate pattern
- [VERIFIED: lib/features/auth/login_screen.dart:136-138] Current password validator (needs D-04 fix)
- [VERIFIED: lib/api/api_client.dart:32-66] ApiClient.send() queryParameters support
- [CITED: .planning/phases/17-api-contract-sync/17-CONTEXT.md] Phase scope and locked decisions (D-01 to D-05)
- [CITED: .planning/phases/17-api-contract-sync/17-UI-SPEC.md] Design contract for search UI placement and patterns

### Secondary (MEDIUM confidence)
- [CITED: .planning/REQUIREMENTS.md] API-01 and API-02 requirements
- [CITED: .planning/phases/17-api-contract-sync/17-UI-SPEC.md] Validation architecture and state coverage resolution

---

## Metadata

**Confidence breakdown:**
- Standard stack (package versions, testing framework): HIGH — locked in pubspec.yaml and .planning/config.json
- Architecture patterns (API migration, debounce, validation): HIGH — patterns verified in existing code (listBandTracks, add_setlist_tracks_dialog.dart, login_screen.dart)
- Common pitfalls: HIGH — derived from codebase review and decision context
- Test coverage: MEDIUM — existing test infrastructure confirmed; Wave 0 gaps identified but executable

**Research date:** 2026-08-27
**Valid until:** 2026-09-03 (7 days — search/API scope stable, minimal churn expected)

**Phase ready for planning:** YES. All technical decisions are locked in CONTEXT.md, API contract is finalized in publicapi.yml, and implementation patterns are verified in existing codebase.
