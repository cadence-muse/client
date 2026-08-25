<!-- refreshed: 2026-08-25 -->
# Architecture

**Analysis Date:** 2026-08-25

## System Overview

```text
┌──────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  ┌──────────────┬─────────────────┬────────────────────────┐ │
│  │ Auth         │ Features        │ Navigation             │ │
│  │ LoginScreen  │ (Bands, Tracks, │ RootScaffold           │ │
│  │              │  Setlists, etc) │ (bottom nav tabs)      │ │
│  └──────────────┴─────────────────┴────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────┘
                             │
                    ┌────────▼───────┐
                    │ Riverpod        │
                    │ Providers       │
                    │ (State Mgmt)    │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
    ┌───▼────────┐  ┌───────▼─────┐   ┌─────────▼────┐
    │ API Layer  │  │ Cache Layer │   │ Config/Theme │
    │ ApiClient  │  │ CacheService│   │ AppConfig    │
    │ PublicApi  │  │ (Hive)      │   │ AppTheme     │
    │ TokenStore │  │             │   │              │
    └────────────┘  └─────────────┘   └──────────────┘
        │
        │ (HTTP)
        │
    ┌───▼─────────────────┐
    │ Backend API         │
    │ (publicapi.yml)     │
    └─────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| **CadenceApp** | App root, theme setup, Riverpod wrapping | `lib/app.dart` |
| **AuthGate** | Auth state guard, shows login/authenticated content | `lib/features/auth/auth_gate.dart` |
| **RootScaffold** | Bottom navigation, IndexedStack for tab state, offline banner | `lib/navigation/root_scaffold.dart` |
| **Feature Screens** | Home, Bands, Tracks, Setlists, Profile tabs | `lib/features/{feature}/{feature}_screen.dart` |
| **AuthSession** | Auth state provider (token + sign in/out) | `lib/providers/auth_provider.dart` |
| **ApiClient** | HTTP facade, auth header injection, 403 auto-logout | `lib/api/api_client.dart` |
| **PublicApi** | Type-safe API methods (register, login, logout, bands, tracks, etc.) | `lib/api/public_api.dart` |
| **TokenStorage** | Secure token persistence via flutter_secure_storage | `lib/api/token_storage.dart` |
| **CacheService** | Read-only offline cache via Hive (one box per endpoint) | `lib/cache/cache_service.dart` |
| **Connectivity Provider** | Device radio state + isOnline boolean signal | `lib/providers/connectivity_provider.dart` |
| **Data Providers** | Online-first fetch + cache fallback (BandsListData, TracksData, etc.) | `lib/providers/{feature}_provider.dart` |
| **ThemeController** | Theme mode state (system/light/dark) | `lib/providers/theme_provider.dart` |

## Pattern Overview

**Overall:** Online-first reactive architecture with offline read-only caching

**Key Characteristics:**
- **Riverpod-driven**: All state lives in providers; UI watches providers and reacts to changes
- **Online-first caching**: Always try network first; if it fails and cache exists, show cached data silently; if offline with no cache, show OfflineNoCacheException
- **Read-only offline**: No offline mutation queue; offline mode is view-only (all write actions disabled)
- **Persistent auth**: Token persisted securely; restored on app start; auto-logout on 403
- **Tab state persistence**: IndexedStack keeps tabs alive between switches; re-selecting a tab invalidates its provider to fetch fresh data
- **Single connectivity signal**: One global isOnlineProvider watched by all data providers; offline banner at root
- **Platform-aware HTTP**: Conditional imports for different HTTP client creation per platform (web vs native)

## Layers

**UI Layer:**
- Purpose: Display features, handle user interaction, navigate between screens
- Location: `lib/features/`, `lib/navigation/`, `lib/widgets/`
- Contains: Feature screens (StatelessWidget/ConsumerWidget), dialogs, navigation structure
- Depends on: Riverpod providers, app theme
- Used by: MaterialApp (home) and feature navigation
- Key files: 
  - `lib/features/auth/login_screen.dart` - Auth UI (login/signup)
  - `lib/features/bands/bands_screen.dart` - Bands list tab
  - `lib/features/tracks/tracks_screen.dart` - Tracks list tab
  - `lib/features/setlists/setlists_screen.dart` - Setlists tab
  - `lib/navigation/root_scaffold.dart` - Root navigation with bottom tabs

**Provider/State Layer:**
- Purpose: Reactive state management, data fetching, offline logic
- Location: `lib/providers/`
- Contains: Riverpod providers (classes with `@riverpod` annotation, generated via code generation)
- Depends on: API layer (via publicApiProvider), cache layer, connectivity provider
- Used by: UI layer via `ref.watch()` and `ref.read()`
- Key files:
  - `lib/providers/auth_provider.dart` - AuthSession class, token state, apiClientProvider
  - `lib/providers/bands_provider.dart` - BandsListData, band detail providers
  - `lib/providers/tracks_provider.dart` - Tracks list and detail providers
  - `lib/providers/setlists_provider.dart` - Setlists list and detail providers
  - `lib/providers/connectivity_provider.dart` - isOnlineProvider, connectivity stream
  - `lib/providers/navigation_provider.dart` - Tab index state

**API Layer:**
- Purpose: HTTP communication, auth token management, token persistence
- Location: `lib/api/`
- Contains: ApiClient (HTTP wrapper), PublicApi (business-logic methods), TokenStorage (secure persistence)
- Depends on: http package, flutter_secure_storage, config (for base URL)
- Used by: Provider layer (via publicApiProvider and apiClientProvider)
- Key files:
  - `lib/api/api_client.dart` - HTTP client with auth header injection, 403 handler
  - `lib/api/public_api.dart` - API methods (register, login, logout, listBands, getBand, etc.)
  - `lib/api/token_storage.dart` - Secure storage wrapper
  - `lib/api/api_exception.dart` - Exception type for API errors (statusCode, code, message)
  - `lib/api/publicapi.yml` - OpenAPI spec (source of truth for all endpoints)

**Cache Layer:**
- Purpose: Read-only offline storage via Hive (local database)
- Location: `lib/cache/`
- Contains: CacheService with one Hive box per endpoint type (profiles, bands, tracks, setlists)
- Depends on: Hive package, riverpod_annotation
- Used by: Provider layer (data providers read/write cache)
- Key files:
  - `lib/cache/cache_service.dart` - CacheService singleton, Hive box management, read/write methods for each endpoint

**Config/Theme Layer:**
- Purpose: App-wide configuration and visual theming
- Location: `lib/config/`, `lib/theme/`
- Contains: AppConfig (API base URL), AppTheme (light/dark theme definitions)
- Depends on: Flutter Material
- Used by: App root (CadenceApp) and theme provider
- Key files:
  - `lib/config/app_config.dart` - API_BASE_URL from dart-define
  - `lib/theme/app_theme.dart` - ThemeData definitions for light/dark

## Data Flow

### Primary Request Path (Fetch Band List Online)

1. **UI watches provider** → `ref.watch(bandsListDataProvider)` (`lib/features/bands/bands_screen.dart:30`)
2. **Provider build runs** → `BandsListData.build()` checks `isOnlineProvider` (`lib/providers/bands_provider.dart:39-63`)
3. **Online, fetch from API** → calls `ref.read(publicApiProvider).listBands()` → `ApiClient.send()` injects auth token (`lib/api/api_client.dart:32-66`)
4. **Success → cache and return** → `CacheService.writeBands()` stores response, provider emits AsyncData(bands) (`lib/providers/bands_provider.dart:65-69`)
5. **UI rebuilds** → BandsScreen.build() receives AsyncData(bands), renders list (`lib/features/bands/bands_screen.dart:47-48`)

### Offline Request Path (Cache Fallback)

1. **Same as above until step 3**
2. **Fetch throws** → catch block runs (`lib/providers/bands_provider.dart:44-54`)
3. **Try cache** → `CacheService.readBands()` returns previously saved data if exists
4. **Success → return cached data silently** → no error shown to user (silent fallback)
5. **If no cache → rethrow as AsyncError** → UI shows error state with Retry button

### Offline Request Path (No Cache)

1. **UI watches provider** → `ref.watch(bandsListDataProvider)` 
2. **isOnlineProvider is false** → provider build skips network call
3. **Try cache** → `CacheService.readBands()` returns null (nothing cached yet)
4. **Throw OfflineNoCacheException** → provider emits AsyncError(OfflineNoCacheException)
5. **UI shows OfflineNoCacheView** → message + explanation, Retry button greyed out until online

### Auth Restoration on App Start

1. **main.dart runs** → `Hive.initFlutter()` + `CacheService.initialize()` then `runApp(ProviderScope(CadenceApp))` (`lib/main.dart:8-14`)
2. **CadenceApp builds** → AuthGate watches `authSessionProvider` (`lib/app.dart:22`, `lib/features/auth/auth_gate.dart:19`)
3. **AuthSession.build() runs** → `ref.watch(tokenStorageProvider).read()` restores token from secure storage (`lib/providers/auth_provider.dart:34`)
4. **Token restored** → AsyncData(token) → AuthGate shows authenticated content
5. **Token missing/corrupted** → AsyncData(null) → AuthGate shows LoginScreen

### 403 Response Auto-Logout

1. **API request returns 403** → `ApiClient.send()` detects status code (`lib/api/api_client.dart:56-58`)
2. **onUnauthorized callback fires** → `ref.read(authSessionProvider.notifier).signOut()` (`lib/providers/auth_provider.dart:18`)
3. **signOut() clears token** → `TokenStorage.delete()` + `CacheService.clearAll()` (`lib/providers/auth_provider.dart:64-66`)
4. **AuthSession emits AsyncData(null)** → AuthGate automatically switches to LoginScreen

### Theme Change Flow

1. **User toggles theme in settings** → calls `ref.read(themeControllerProvider.notifier).setThemeMode(ThemeMode.dark)` 
2. **ThemeController state updates** → emits new ThemeMode (`lib/providers/theme_provider.dart:11`)
3. **CadenceApp watches themeControllerProvider** → `ref.watch(themeControllerProvider)` (`lib/app.dart:14`)
4. **MaterialApp rebuilds** with new `themeMode` → theme updates across entire app

**State Management:**
- **AuthSession, ThemeController, Providers**: Riverpod classes with `@riverpod` annotation; state mutated via notifier methods
- **UI State**: Local widget state (TextEditingController, form errors) managed in ConsumerStatefulWidget where needed
- **Connectivity**: Stream-based (connectivity_plus onConnectivityChanged) mapped to global isOnlineProvider boolean
- **Cross-layer**: Dependency injection via Riverpod; providers declare dependencies via `ref.watch()` and `ref.read()` at build/action time

## Key Abstractions

**AuthSession Provider:**
- Purpose: Single source of truth for auth token and sign-in/out logic
- Examples: `lib/providers/auth_provider.dart` — defines AuthSession Riverpod class
- Pattern: AsyncValue<String?> (token or null); signIn(token) and signOut() methods; reentry guard on signOut

**ApiClient Facade:**
- Purpose: Encapsulate HTTP communication, auth header injection, error handling
- Examples: `lib/api/api_client.dart`
- Pattern: `send(method, path, body?, queryParameters?, requireAuth?)` returns Map or null; throws ApiException on 4xx/5xx

**PublicApi Business Logic:**
- Purpose: Type-safe API methods corresponding to OpenAPI spec operations
- Examples: `lib/api/public_api.dart` — `register()`, `login()`, `logout()`, `listBands()`, `getBand()`, etc.
- Pattern: Methods wrap ApiClient.send(), return typed values (String token, List<Map>, Map, etc.)

**Online-First Data Providers:**
- Purpose: Reactive fetch with cache fallback and offline detection
- Examples: `lib/providers/bands_provider.dart` (BandsListData), `lib/providers/tracks_provider.dart` (TracksData)
- Pattern: Riverpod class with Future<T> build(); watches isOnlineProvider; on build, try network (with cache fallback), or serve cache offline, or throw OfflineNoCacheException

**CacheService Singleton:**
- Purpose: Centralized Hive-backed read/write access for all offline data
- Examples: `lib/cache/cache_service.dart`
- Pattern: One-box-per-endpoint (profileBox, bandsBox, tracksBox, setlistsBox); read(key), write(key, data), clear(); wrapped in cacheServiceProvider

**Feature Screens:**
- Purpose: Encapsulate feature UI for one tab or detail page
- Examples: `lib/features/bands/bands_screen.dart`, `lib/features/tracks/tracks_screen.dart`, `lib/features/profile/profile_screen.dart`
- Pattern: ConsumerWidget/ConsumerStatefulWidget; watch providers for data; handle data/loading/error states; dispatch actions via ref.read()

## Entry Points

**main.dart:**
- Location: `lib/main.dart`
- Triggers: App launch (flutter run)
- Responsibilities: 
  - Initialize Flutter bindings (WidgetsFlutterBinding.ensureInitialized)
  - Initialize Hive (Hive.initFlutter)
  - Initialize CacheService (load Hive boxes)
  - Wrap app in ProviderScope (Riverpod root)
  - Call runApp(CadenceApp)

**CadenceApp:**
- Location: `lib/app.dart`
- Triggers: Called from main()
- Responsibilities:
  - Set up MaterialApp (title, theme, themeMode)
  - Watch themeControllerProvider for theme changes
  - Render AuthGate as home (guards authenticated content)
  - Responsive to theme mode (light/dark/system)

**AuthGate:**
- Location: `lib/features/auth/auth_gate.dart`
- Triggers: Rendered as MaterialApp.home
- Responsibilities:
  - Watch authSessionProvider to check if user is logged in
  - Show LoginScreen if token is null
  - Show builder(context) [RootScaffold] if token exists
  - Handle loading state (spinner) and error state (error message)
  - Automatically respond to token changes (e.g., 403 → logout → show LoginScreen)

**LoginScreen:**
- Location: `lib/features/auth/login_screen.dart`
- Triggers: Shown by AuthGate when not authenticated
- Responsibilities:
  - Collect username/password via form
  - Call publicApi.register() then publicApi.login() for signup
  - Call publicApi.login() for login
  - Store token via authSessionProvider.notifier.signIn()
  - Handle specific API error codes (401 → invalid credentials, 400 + already_exists → username taken)
  - Show error messages to user

**RootScaffold:**
- Location: `lib/navigation/root_scaffold.dart`
- Triggers: Shown by AuthGate when authenticated
- Responsibilities:
  - Render offline banner at top (watches isOnlineProvider)
  - Render IndexedStack with 5 tabs (Home, Bands, Tracks, Setlists, Profile)
  - Manage tab selection via selectedTabIndexProvider
  - Invalidate tab providers on re-select to fetch fresh data

## Architectural Constraints

- **State management framework**: Riverpod (code-generated `@riverpod` classes); no GetIt or Provider package; no manual ChangeNotifier
- **Single HTTP client**: All API calls via one ApiClient instance (apiClientProvider); ensures consistent auth handling
- **Persistent auth token**: Only auth token is saved to disk (TokenStorage); all other state is in-memory (lost on app restart)
- **Offline scope**: Read-only (no offline write queue, no conflict resolution); simplifies v1 scope; all write actions disabled when offline
- **Platform-specific HTTP**: Conditional imports for web vs native HTTP client creation; auth header handling differs (web needs cross-origin support)
- **No local database models**: CacheService stores raw decoded JSON (Map<String, dynamic>) not typed Dart classes; reuses same fromJson-free decode path as network
- **Tab state persistence via IndexedStack**: Tabs stay alive between switches (not rebuilt), so data providers must be invalidated manually on re-select
- **Single global connectivity signal**: isOnlineProvider (bool, derived from connectivity_plus stream) watched by all data providers; prevents per-tab connectivity inconsistency
- **No auth state in local shared preferences**: Token only in flutter_secure_storage (Android Keystore / iOS Keychain); not plain SharedPreferences
- **Reentrancy guard on signOut**: 403 response triggers onUnauthorized → signOut, which would trigger another 403 if not guarded; _loggingOut flag prevents infinite recursion

## Anti-Patterns

### Imperative Cache Management

**What happens:** Code manually checks cache before fetching, or uses conditional logic to decide when to refresh.

**Why it's wrong:** Leads to inconsistent offline behavior across features; harder to maintain; prone to stale data.

**Do this instead:** Follow the online-first pattern in `lib/providers/bands_provider.dart` — providers declare offline logic once, UI layer doesn't know about cache.

### Holding Auth State in Widget Tree

**What happens:** Passing token or auth status down via constructor parameters or scoped widgets instead of via provider.

**Why it's wrong:** Creates prop drilling; hard to respond to 403 logout from deep in tree; token access becomes scattered.

**Do this instead:** authSessionProvider is the single source of truth; read it via `ref.read(authSessionProvider)` or `ref.watch(authSessionProvider)` in any provider or widget.

### Mixing Connectivity State per Tab

**What happens:** Each tab has its own connectivity listener or re-checks network state independently.

**Why it's wrong:** Tabs can disagree on connectivity state; increases coupling to connectivity_plus; harder to test.

**Do this instead:** All data providers watch isOnlineProvider (one global boolean); offline banner watches same signal; ensures consistent behavior across app.

### Not Invalidating Provider on Tab Re-select

**What happens:** Tab data stays stale when user re-selects the tab and expects fresh data.

**Why it's wrong:** IndexedStack keeps tab alive; provider build() only runs once per app session; user taps refresh button expecting new data but gets old data.

**Do this instead:** BandsScreen (and other tabs) listen to selectedTabIndexProvider and call `ref.invalidate(bandsListDataProvider)` when re-selected (see `lib/features/bands/bands_screen.dart:26-28`).

### Throwing Raw ApiException in UI

**What happens:** UI layer catches ApiException and tries to switch on statusCode/code inline.

**Why it's wrong:** Scattered error handling; hard to test; error messages not localized.

**Do this instead:** Provider or PublicApi layer should interpret API errors and throw application-level exceptions or map to user-friendly messages; LoginScreen already does this well (401 → "Invalid credentials", 400 + already_exists → "Username taken").

## Error Handling

**Strategy:** Exceptions propagate from ApiClient → PublicApi → Providers → UI; each layer adds context; UI layer surfaces errors to user.

**Patterns:**
- **Network errors**: ApiClient throws ApiException(statusCode, code, message); Provider catches and retries/falls back to cache; UI shows error with Retry button
- **403 Unauthorized**: ApiClient detects 403, calls onUnauthorized callback immediately, then throws ApiException; callback signs out (clears token/cache); AuthGate automatically shows LoginScreen
- **Offline with no cache**: Provider throws OfflineNoCacheException; UI shows OfflineNoCacheView with message "No cached data"; Retry button greyed out until online
- **JSON parsing failures**: ApiClient.fromResponse() catches malformed error JSON, falls back to generic "Request failed" message
- **Cache write failures**: CacheService write methods return bool; callers treat false as non-critical (network data still served in-memory)
- **Reentrancy on 403**: AuthSession._loggingOut flag prevents logout() from recursive-calling itself if logout() request gets 403

## Cross-Cutting Concerns

**Logging:** No structured logging in current codebase; no print() statements; consider adding provider-level logging for network calls and cache hits in future iterations.

**Validation:** 
- Client-side form validation in LoginScreen (required fields)
- Server-side validation on all write operations (returned as 400 errors with `code` field)
- Special handling: 401 on login (invalid credentials), 400 + "already_exists" on register (username taken), 400 + "invalid_input" on password change (wrong current password)

**Authentication:**
- Token-based via Authorization header
- Token persisted in flutter_secure_storage (Android Keystore, iOS Keychain)
- Restored on app start via AuthSession.build()
- Auto-logout on 403 via ApiClient.onUnauthorized callback
- Logout best-effort: fires logout() request but always succeeds locally regardless of network outcome

**Offline Handling:**
- Connectivity detection via connectivity_plus (radio state, not active ping)
- One global isOnlineProvider boolean signal
- Data providers implement online-first pattern: try network, fallback to cache, or throw OfflineNoCacheException
- All write actions (create/update/delete) disabled when offline (FloatingActionButton and form buttons disabled)
- Offline banner shown at top of screen when offline; includes message "Showing cached data — may be out of date"

---

*Architecture analysis: 2026-08-25*
