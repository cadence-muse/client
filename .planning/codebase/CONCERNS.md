# Codebase Concerns

**Analysis Date:** 2026-08-13

## Tech Debt

### Incomplete Feature Implementation

**Areas affected:**
- `lib/features/home/home_screen.dart` - Shows placeholder text "Home" only
- `lib/features/songs/songs_screen.dart` - Shows placeholder text "Songs" only
- `lib/features/profile/profile_screen.dart` (line 25-29) - Shows hardcoded "Username" text instead of fetching actual user data
- `lib/features/bands/bands_screen.dart` (line 8-12) - Uses hardcoded mock data instead of API calls

**Impact:** Screens are not functional. Users cannot view real band, song, or profile data. Mock data is not representative of actual API responses.

**Fix approach:** Replace placeholder implementations with:
1. API client methods to fetch bands, songs, and user profile from backend
2. State management to handle loading/error states
3. Display actual data in UI based on API responses

### Theme Persistence Not Implemented

**Files:** `lib/theme/theme_controller.dart` (line 3-6)

**Issue:** ThemeController creates a fresh ThemeMode.system on app startup. Selected theme preference is not persisted across app restarts.

**Impact:** Users lose their theme preference every time they close and reopen the app.

**Fix approach:** 
1. Add persistent storage (SharedPreferences) to ThemeController
2. Load saved theme on app startup in main.dart or ThemeController constructor
3. Save theme changes when user selects new theme

### RadioGroup Widget Missing from pubspec.yaml

**File:** `lib/features/settings/settings_screen.dart` (line 17)

**Issue:** Code uses `RadioGroup<ThemeMode>` but this widget is not imported or defined anywhere in the codebase. It's also not in `pubspec.yaml` dependencies.

**Impact:** Code will not compile. SettingsScreen will fail at runtime if somehow compiled.

**Fix approach:**
1. Either add missing dependency to pubspec.yaml, or
2. Replace RadioGroup with standard Flutter widgets (RadioListTile works without wrapper as shown in lines 26-37)

## Known Bugs

### Async Token Restoration Without Error Handling

**File:** `lib/features/auth/auth_gate.dart` (line 31)

**Issue:** `authSession.restore()` is called in `initState()` without `await`. The restore call is a Future but not awaited, meaning the UI can render before token is restored.

**Symptoms:** 
- First screen flash shows loading indicator briefly even when token is cached
- Race condition between UI build and token read from secure storage

**Workaround:** None - UI will flash loading state

**Fix approach:** 
1. Use FutureBuilder or defer build until restore() completes
2. Or handle restore() completion notification properly

### Auth Session Restore May Fail Silently

**File:** `lib/api/auth_session.dart` (line 24-28)

**Issue:** `restore()` calls `tokenStorage.read()` with no error handling. If secure storage access fails (permission denied, storage corrupted), exception is not caught or reported.

**Impact:** Token may not be restored if secure storage is unavailable, silently signing user out.

**Fix approach:** Add try-catch in restore() to handle storage errors gracefully and log them.

## Security Considerations

### Weak Password Validation

**File:** `lib/features/auth/login_screen.dart` (line 129)

**Issue:** Password validation only checks minimum length (8 characters). No validation for:
- Complexity (uppercase, lowercase, numbers, special characters)
- Common patterns or dictionary words
- User data in password (username, etc.)

**Risk:** Users can set weak passwords that are vulnerable to brute force or dictionary attacks.

**Current mitigation:** Server-side validation (assumed)

**Recommendations:**
1. Add client-side password strength meter
2. Implement password policy validation (complexity requirements)
3. Warn users about weak passwords before submission

### No Input Sanitization on Login

**File:** `lib/features/auth/login_screen.dart` (line 41-42)

**Issue:** Username and password are read directly from form fields with only trim() on username, then sent to server.

**Risk:** If server-side sanitization is missing, could be vulnerable to injection attacks. Client should validate format.

**Current mitigation:** Server-side validation (assumed)

**Recommendations:**
1. Add max length validation for username (e.g., max 255 chars)
2. Validate username format (alphanumeric + allowed special chars only)
3. Implement rate limiting on login attempts

### No Timeout on HTTP Requests

**File:** `lib/api/api_client.dart` (line 49)

**Issue:** HTTP requests have no timeout configured. Network hangs could cause app to freeze indefinitely.

**Risk:** DoS vulnerability - malicious server or network conditions could hang app.

**Current mitigation:** None

**Recommendations:**
1. Add 30-second timeout to all HTTP requests in ApiClient
2. Display error message to user if timeout occurs
3. Implement retry logic with exponential backoff

### Cookie-Based Auth on Native Platforms

**File:** `lib/api/api_client.dart` (line 42-43)

**Issue:** Tokens are passed as `Cookie` header on native platforms (iOS/Android). HttpClient cookie jar is in-memory only and lost on restart (per comments), which is why we explicitly forward tokens.

**Risk:** 
- If HttpClient auto-manages cookies, there's no guarantee our explicit header matches
- Cookie storage is not persistent by design
- Inconsistent auth behavior between web and native

**Current mitigation:** Token is stored in secure storage and restored on app startup

**Recommendations:**
1. Document the auth flow clearly for future maintainers
2. Consider adding integration tests for auth on each platform
3. Log auth failures for debugging

## Performance Bottlenecks

### Bottom Navigation Keeps All Screens in Memory

**File:** `lib/navigation/root_scaffold.dart` (line 33)

**Issue:** `IndexedStack` creates all four screen widgets (Home, Songs, Bands, Profile) at app startup and keeps them all in memory, even though only one is visible.

**Symptoms:** 
- Higher memory usage than necessary
- Slower app startup if screens become complex
- All screens make API calls on app launch (if implemented)

**Cause:** IndexedStack maintains state of all children for instant tab switching

**Improvement path:**
1. For simple screens, IndexedStack is acceptable
2. For complex screens with API calls, implement lazy loading:
   - Use PageView or custom navigation
   - Only build screen when tab is selected
   - Cache screen state once built

### No API Response Caching

**File:** `lib/api/api_client.dart` and `lib/api/public_api.dart`

**Issue:** Every screen reload or navigation back to a screen makes a fresh API call. No response caching implemented.

**Impact:** Unnecessary network requests, slower perceived performance, higher server load.

**Improvement path:**
1. Add simple in-memory cache layer in ApiClient
2. Implement cache invalidation strategy (TTL or manual)
3. Add "pull-to-refresh" UI pattern to allow manual cache refresh

## Fragile Areas

### AuthSession State Management

**Files:** `lib/api/auth_session.dart`, `lib/features/auth/auth_gate.dart`

**Why fragile:**
- Multiple paths modify state: signIn(), signOut(), restore()
- 403 responses auto-call signOut() in ApiClient, which also modifies AuthSession
- No logging of state transitions makes debugging difficult
- No validation that state transitions are valid (e.g., can't restore while authenticated)

**Safe modification:**
1. Always use setter methods (signIn, signOut, restore) - never modify _status or _token directly
2. Add logging to each state transition
3. Add state validation in each method
4. Consider using a state machine pattern for clearer transitions

**Test coverage gaps:**
- No tests for restore() with missing token
- No tests for restore() with corrupted token
- No tests for signOut() while offline
- No tests for 403 response triggering signOut()

### Login Screen Error Handling

**File:** `lib/features/auth/login_screen.dart` (lines 44-76)

**Why fragile:**
- Nested try-catch blocks with different error handling paths
- Code path differs based on auth mode (login vs sign-up)
- Error messages are user-facing strings built in setState() callback
- If _isSubmitting flag is not set properly, button can be tapped multiple times

**Safe modification:**
1. Extract error handling to separate methods
2. Use constants for user-facing error messages
3. Add comprehensive error tests
4. Test each auth mode separately

**Test coverage gaps:**
- No tests for username already exists scenario
- No tests for invalid credentials
- No tests for network errors
- No tests for concurrent submissions (race conditions)

### HTTP Client Factory Platform Detection

**Files:** `lib/api/http_client_factory.dart`, `lib/api/http_client_factory_*.dart`

**Why fragile:**
- Conditional imports rely on Dart compile-time detection
- Stub fallback (`http_client_factory_stub.dart`) may be used unexpectedly
- No tests to verify correct client is instantiated on each platform
- Silent fallback makes bugs hard to detect

**Safe modification:**
1. Add logging when http client is created
2. Add unit tests that verify correct client is used
3. Consider asserting in app startup that correct client was selected

**Test coverage gaps:**
- No tests verify web client has credentials enabled
- No tests verify native client creates correct http.Client
- No tests for credential handling differences

## Scaling Limits

### Authentication System Hardcoded for Single Backend

**Files:** `lib/config/app_config.dart`, `lib/api/public_api.dart`

**Issue:** API base URL is hardcoded per environment. If backend is deployed across regions or multiple instances, no way to handle:
- Failover to alternate server
- Region-specific endpoints
- Load balancing across endpoints

**Limit:** Single point of failure - if backend is down, app cannot function

**Scaling path:**
1. Implement service discovery or configuration server
2. Add fallback endpoints for redundancy
3. Implement health checks to detect dead backends
4. Add region selection UI if multi-region needed

## Missing Critical Features

### No Error Logging or Analytics

**Issue:** Errors in API requests, auth failures, or app crashes are not logged anywhere. No way to debug issues in production.

**Blocks:** Cannot diagnose user-reported bugs. Cannot identify patterns of failures.

**Fix approach:**
1. Add logging framework (e.g., logger package)
2. Log all API errors with full stack trace
3. Implement crash reporting (Firebase Crashlytics or Sentry)
4. Add analytics to track auth failures

### No Network State Detection

**Issue:** App doesn't detect when network is offline. API errors look like server errors.

**Blocks:** Cannot show "You're offline" UI or queue requests for retry when online.

**Fix approach:**
1. Add connectivity_plus package to detect network state
2. Show banner/snackbar when offline
3. Implement request queuing for offline mode

### No Global Error Handling

**Issue:** Each screen/API call handles errors independently. No consistent error handling or user feedback.

**Blocks:** Inconsistent user experience, some errors may be silently ignored.

**Fix approach:**
1. Add error boundary widget (global error handler)
2. Implement consistent error UI (snackbars, dialogs, error screens)
3. Add logging middleware to all API calls

## Test Coverage Gaps

### Integration Tests Missing for Auth Flow

**File:** `test/widget_test.dart`

**What's not tested:**
- Login with invalid credentials
- Sign-up flow with validation errors
- Token restoration on cold start
- Session timeout (403 response)
- Logout flow
- Network errors during auth

**Files affected:**
- `lib/features/auth/login_screen.dart` (0% coverage - no unit tests)
- `lib/api/auth_session.dart` (0% coverage)
- `lib/api/api_client.dart` (0% coverage)

**Risk:** Auth system changes could break security without being caught.

**Priority:** High - auth is critical path

### No Unit Tests for API Client

**Files affected:**
- `lib/api/api_client.dart` (no tests)
- `lib/api/api_exception.dart` (no tests)
- `lib/api/public_api.dart` (no tests)

**Missing tests:**
- HTTP status code handling (4xx, 5xx)
- Request body encoding
- Response parsing
- Cookie header on native platforms
- 403 auto-logout behavior

**Risk:** API changes could silently fail. Cookie handling could diverge between platforms.

**Priority:** High

### No Tests for Form Validation

**Files affected:**
- `lib/features/auth/login_screen.dart` - username/password validation not tested

**Missing tests:**
- Empty username validation
- Short password validation
- Long input handling
- Special characters in username

**Risk:** Form validation could be broken by refactoring.

**Priority:** Medium

---

*Concerns audit: 2026-08-13*
