<!-- refreshed: 2026-08-13 -->
# Architecture

**Analysis Date:** 2026-08-13

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                      CadenceApp (Root)                       │
│                    `lib/app.dart`                            │
│          Manages theme with ListenableBuilder               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│                      AuthGate                                │
│                `lib/features/auth/auth_gate.dart`            │
│     Shows LoginScreen or authenticated app content          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│              RootScaffold (Bottom Navigation)                │
│            `lib/navigation/root_scaffold.dart`               │
│      IndexedStack manages 4 screens via NavigationBar        │
├──────────┬─────────────┬───────────────┬────────────────────┤
│   Home   │    Songs    │     Bands     │     Profile        │
│ Screen   │   Screen    │    Screen     │     Screen         │
└──────────┴─────────────┴───────────────┴────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    API & Auth Layer                          │
│                    `lib/api/`                                │
│  ApiClient - HTTP wrapper, token management, error handling │
│  AuthSession - Auth state & persistence (ChangeNotifier)   │
│  PublicApi - High-level API methods (login, register)       │
│  TokenStorage - Secure token persistence                    │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| CadenceApp | App root, theme management, dependency injection | `lib/app.dart` |
| AuthGate | Guards app with auth state, shows LoginScreen or authenticated content | `lib/features/auth/auth_gate.dart` |
| RootScaffold | Bottom navigation, tab management using IndexedStack | `lib/navigation/root_scaffold.dart` |
| HomeScreen | Home tab (placeholder) | `lib/features/home/home_screen.dart` |
| SongsScreen | Songs tab (placeholder) | `lib/features/songs/songs_screen.dart` |
| BandsScreen | Bands tab (placeholder) | `lib/features/bands/bands_screen.dart` |
| ProfileScreen | Profile tab with settings | `lib/features/profile/profile_screen.dart` |
| LoginScreen | Auth UI for login/signup | `lib/features/auth/login_screen.dart` |
| ApiClient | HTTP client with auth token attachment, 403 auto-logout | `lib/api/api_client.dart` |
| AuthSession | Auth state manager (ChangeNotifier) | `lib/api/auth_session.dart` |
| PublicApi | Register/login API methods | `lib/api/public_api.dart` |
| TokenStorage | Secure token persistence using flutter_secure_storage | `lib/api/token_storage.dart` |
| ThemeController | Theme mode management (ValueNotifier) | `lib/theme/theme_controller.dart` |
| AppTheme | Light/dark theme definitions | `lib/theme/app_theme.dart` |
| AppConfig | Build-time configuration (API base URL) | `lib/config/app_config.dart` |

## Pattern Overview

**Overall:** Layered architecture with reactive state management

**Key Characteristics:**
- **Authentication gating:** AuthGate wraps authenticated content, prevents unauthenticated access
- **Reactive state:** Uses ChangeNotifier (AuthSession, ThemeController) and ListenableBuilder for UI updates
- **Dependency injection:** Dependencies injected into main widget and propagated down (prop drilling)
- **Platform-aware:** Uses conditional imports for platform-specific HTTP client implementations
- **Token persistence:** Secure storage with automatic restoration on app start
- **Single HTTP client:** Centralized ApiClient handles all requests, auth, and error handling

## Layers

**UI Layer:**
- Purpose: Display features, handle user interaction
- Location: `lib/features/*/` and `lib/navigation/`
- Contains: Feature screens (StatelessWidget/StatefulWidget), navigation widget
- Depends on: API layer (via dependency injection), theme
- Used by: Directly rendered by root app

**API/Auth Layer:**
- Purpose: HTTP communication, authentication state, token persistence
- Location: `lib/api/`
- Contains: ApiClient, AuthSession, PublicApi, TokenStorage
- Depends on: http package, flutter_secure_storage
- Used by: UI layer via dependency injection

**Config/Theme Layer:**
- Purpose: App-wide configuration and theming
- Location: `lib/config/`, `lib/theme/`
- Contains: AppConfig, ThemeController, AppTheme
- Depends on: Nothing (core Flutter)
- Used by: Root app widget (CadenceApp)

## Data Flow

### Primary Request Path (Authenticated API Call)

1. **User action triggers API call** (`lib/features/*/` screen)
   - Example: LoginScreen calls `publicApi.login(username, password)`

2. **PublicApi method invokes ApiClient** (`lib/api/public_api.dart:22-31`)
   - Calls `_client.send('POST', '/api/login', body: {...})`

3. **ApiClient prepares HTTP request** (`lib/api/api_client.dart:32-62`)
   - Reads token from `authSession.token`
   - On native platforms: attaches token as `Cookie` header (web browser does this automatically)
   - Sends HTTP request via platform-specific `http.Client`

4. **Response handling**
   - On 403: `authSession.signOut()` is called (line 53) → auto-logout
   - On 4xx/5xx: throw `ApiException`
   - On success: parse JSON and return

5. **State update** (`lib/api/auth_session.dart:30-35`)
   - On login: `signIn(token)` → stores token, updates status to `authenticated`, calls `notifyListeners()`

6. **UI reacts to auth state** (`lib/app.dart:24-32`)
   - `ListenableBuilder` listens to `themeController`
   - AuthGate listens to `authSession` status
   - When status changes, UI rebuilds and shows authenticated content

### Theme Change Flow

1. User taps theme toggle in ProfileScreen
2. Calls `themeController.setThemeMode(mode)` 
3. ThemeController (ValueNotifier) updates value → notifies listeners
4. CadenceApp's ListenableBuilder rebuilds (line 24-43)
5. MaterialApp's `themeMode` is updated → system applies new theme

### Auth Restoration on App Start

1. `main()` creates AuthSession → passes to CadenceApp
2. AuthGate.initState() calls `authSession.restore()` (line 31)
3. TokenStorage reads persisted token from secure storage
4. AuthSession updates status:
   - Token found → `authenticated`
   - No token → `unauthenticated`
   - Calls `notifyListeners()`
5. AuthGate rebuilds: shows authenticated content or LoginScreen

**State Management:**
- **Auth state:** ChangeNotifier-based reactive (AuthSession)
- **Theme state:** ValueNotifier-based reactive (ThemeController)
- **UI state:** Widget state (LoginScreen, RootScaffold manage local form/navigation state)
- **Cross-layer communication:** Dependency injection + listener pattern

## Key Abstractions

**AuthSession:**
- Purpose: Single source of truth for auth state and token
- Examples: `lib/api/auth_session.dart`
- Pattern: ChangeNotifier with three states (unknown, unauthenticated, authenticated)

**ApiClient:**
- Purpose: Encapsulate HTTP communication, token injection, error handling
- Examples: `lib/api/api_client.dart`
- Pattern: Facade over http.Client, handles auth headers and 403 auto-logout

**PublicApi:**
- Purpose: Type-safe, business-logic-aware API methods
- Examples: `lib/api/public_api.dart`
- Pattern: Wraps ApiClient, provides register() and login() methods

**Feature Screens:**
- Purpose: Encapsulate feature UI
- Examples: `lib/features/*/` (HomeScreen, BandsScreen, etc.)
- Pattern: StatelessWidget for simple screens, StatefulWidget for interactive ones

## Entry Points

**main():**
- Location: `lib/main.dart`
- Triggers: App launch
- Responsibilities:
  - Create AuthSession with TokenStorage
  - Create ApiClient with AuthSession and API base URL
  - Create PublicApi with ApiClient
  - Create ThemeController
  - Launch CadenceApp with all dependencies

**CadenceApp:**
- Location: `lib/app.dart`
- Triggers: Called from main()
- Responsibilities:
  - Set up MaterialApp with theme management
  - Gate authenticated content with AuthGate

**AuthGate:**
- Location: `lib/features/auth/auth_gate.dart`
- Triggers: Rendered as home of MaterialApp
- Responsibilities:
  - Restore persisted auth token on app start
  - Show LoginScreen or authenticated app based on auth status
  - Handle auto-logout on 403 responses

## Architectural Constraints

- **Dependency injection pattern:** No service locators (like GetIt or Provider); dependencies passed via constructor. This makes testing easier but requires prop drilling from root.
- **Single HTTP client:** All API calls go through one ApiClient instance, ensuring consistent auth handling and error responses.
- **State persistence:** Only auth token is persisted; app state is not saved (stateless on restart).
- **Platform-specific code:** HTTP client creation uses conditional imports for web/native platforms; auth header attachment differs by platform.
- **No backend state management:** No local database or offline support; app assumes network access.
- **Authentication ceremony:** Token-based (cookie-like); server validates token on each request. 403 triggers immediate logout.

## Anti-Patterns

### Prop Drilling

**What happens:** Dependencies are passed through multiple widget constructors even when intermediate widgets don't use them. Example: `themeController` and `authSession` passed through RootScaffold to ProfileScreen, but RootScaffold doesn't use them.

**Why it's wrong:** Creates tight coupling; makes refactoring difficult if you want to remove a dependency from an intermediate component. As the app grows, this becomes unmaintainable.

**Do this instead:** Introduce a state management library like Provider, Riverpod, or Bloc that allows widgets to access dependencies without constructor injection. This decouples widget hierarchy from dependency flow.

### Manual Auth Header Management

**What happens:** ApiClient manually attaches auth token as cookie header on native platforms (line 42-44 in `api_client.dart`), but relies on browser to do it automatically on web. This split logic is easy to get wrong.

**Why it's wrong:** Platform-specific logic scattered across the HTTP client makes it fragile. If cookie requirements change, you must update multiple places.

**Do this instead:** Create an interceptor or middleware layer that transparently handles auth injection for all platforms, possibly using an HTTP package wrapper that abstracts away platform differences.

### No Error Recovery

**What happens:** LoginScreen shows generic error messages to users but doesn't retry or provide recovery options. Failed API calls are not queued or retried.

**Why it's wrong:** Poor user experience on network flakiness. Users must manually retry.

**Do this instead:** Implement exponential backoff retry logic in ApiClient or PublicApi; add user-facing "retry" buttons in error states.

## Error Handling

**Strategy:** Throw ApiException on any HTTP error; callers catch and handle

**Patterns:**
- ApiClient throws ApiException for 4xx/5xx responses
- ApiException parses error response JSON for `code` and `message` fields
- LoginScreen catches ApiException, inspects statusCode/code, shows user-friendly message
- 403 responses trigger automatic signOut() in ApiClient before throwing

---

*Architecture analysis: 2026-08-13*
