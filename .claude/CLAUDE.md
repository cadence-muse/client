<!-- GSD:project-start source:PROJECT.md -->

## Project

**Cadence**

Cadence is a Flutter mobile app (Android/iOS, with web build support) for bands to manage their repertoire together: shared song catalog, band membership, and setlists for gigs. Auth, band membership, and secure token persistence already exist; this milestone builds out full band/track/setlist management against the public API and adds offline read caching on mobile.

**Core Value:** A band member can open the app without signal — at a venue, in a basement, on tour — and still see their band's tracks and the setlist for tonight's show.

### Constraints

- **Tech stack**: Flutter/Dart, must reuse existing `ApiClient`/`AuthSession`/`TokenStorage` patterns rather than replacing them — minimize churn on already-working auth
- **Offline scope**: Read-only cache (last-fetched data viewable offline); no offline mutation queue, no conflict resolution — keeps v1 scope bounded
- **Platform scope**: Local caching required on Android/iOS; web excluded this milestone
- **API contract**: `lib/api/publicapi.yml` is the source of truth for all request/response shapes — no inventing fields or endpoints not defined there

<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->

## Technology Stack

## Languages

- Dart 3.12.2+ - Core app language, cross-platform compilation
- Kotlin - Android native code (platform scaffolding)
- Swift - iOS native code (platform scaffolding)
- JavaScript - Web build target

## Runtime

- Flutter SDK (latest stable)
- Dart 3.12.2+ via Flutter SDK
- Android Runtime (APK build target)
- iOS Runtime (iPhone/iPad)
- Web browser (web build target)
- Pub (Dart package manager)
- Lockfile: `pubspec.lock` present
- Dependency resolution: `pubspec.yaml`

## Frameworks

- Flutter - UI framework for iOS, Android, and web
- flutter_test - Built-in Flutter testing framework
- Test runner via `flutter test` command
- flutter_lints 6.0.0 - Linting rules (extends `package:flutter_lints/flutter.yaml`)
- Analysis runner via `flutter analyze`

## Key Dependencies

- http 1.6.0 - HTTP client for REST API communication (`lib/api/api_client.dart`)
- flutter_secure_storage 11.0.0 - Secure token persistence on native platforms
- flutter_secure_storage_platform_interface 2.0.3 - Platform abstraction layer
- cupertino_icons 1.0.8 - iOS-style icon font

## Configuration

- Dart define variables (`--dart-define=` flag)
- Configuration file: `env/config.example.json`
- Example: `flutter run --dart-define-from-file=env/config.json`
- AppConfig located at: `lib/config/app_config.dart`
- `analysis_options.yaml` - Dart analyzer configuration (includes `package:flutter_lints/flutter.yaml`)
- Android: `android/build.gradle.kts`, `android/app/build.gradle.kts`
- iOS: `ios/Runner.xcodeproj`, `ios/Runner.xcworkspace`
- Web: Flutter web build tooling (auto-configured)

## Platform Requirements

- Flutter SDK installed with Dart 3.12.2+
- For Android: Android Studio or command-line Android SDK
- For iOS: Xcode and Apple development tools (macOS)
- For web: No additional requirements beyond Flutter
- Android deployment: Google Play Store (APK/AAB)
- iOS deployment: Apple App Store (IPA)
- Web deployment: Static web host or Flutter web server

<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->

## Conventions

## Naming Patterns

- Dart files use snake_case: `auth_session.dart`, `api_client.dart`, `token_storage.dart`
- Screen files end with `_screen`: `login_screen.dart`, `home_screen.dart`, `bands_screen.dart`
- Directories group by feature or layer: `lib/features/`, `lib/api/`, `lib/theme/`, `lib/navigation/`, `lib/config/`
- Use PascalCase for all classes: `AuthSession`, `ApiClient`, `TokenStorage`, `AuthGate`, `LoginScreen`
- Internal State classes prefixed with underscore: `_AuthGateState`, `_LoginScreenState`, `_RootScaffoldState`
- Exception classes named explicitly: `ApiException`
- Enum cases use lowercase: `AuthStatus.unknown`, `AuthStatus.authenticated`, `AuthStatus.unauthenticated`, `_AuthMode.login`, `_AuthMode.signUp`
- Use camelCase for all functions and methods: `signIn()`, `signOut()`, `restore()`, `register()`, `login()`, `send()`, `setThemeMode()`
- Private methods prefixed with underscore: `_submit()`, `_toggleMode()`
- Named parameters preferred for clarity: `register(username: username, password: password)`
- Use camelCase for local variables and properties: `_token`, `_status`, `_storage`, `_errorMessage`, `_isSubmitting`, `baseUrl`, `authSession`
- Private/internal variables prefixed with underscore: `_httpClient`, `_formKey`, `_usernameController`, `_passwordController`
- Static constants use UPPER_SNAKE_CASE: `_tokenKey = 'auth_token'` (when stored as String constant)
- Configuration values exposed as static constants: `AppConfig.apiBaseUrl`
- Private constants prefixed with underscore: `const _tokenKey = 'auth_token'`

## Code Style

- Dart's built-in formatter (dartfmt) is the standard - apply via `flutter analyze` and `flutter format`
- Line length: follows Dart conventions (typically 80-120 characters)
- Indentation: 2 spaces (Flutter default)
- No explicit import/export aliases - use full relative paths
- Tool: `flutter_lints` 6.0.0 (extends `package:flutter_lints/flutter.yaml`)
- Config: `analysis_options.yaml` at repository root
- Run with: `flutter analyze`
- Default flutter_lints rules are used with no overrides
- All Widget constructors use `const` when possible: `const HomeScreen({super.key})`, `const CadenceApp({super.key, ...})`
- Improves performance and tree stability

## Import Organization

- Not used in current codebase
- All imports use explicit relative paths from root: `import 'package:cadence/...'` for package-relative, or relative `../` paths

## Error Handling

- Use `ApiException` for HTTP-level errors with statusCode, code, and message
- Can be constructed manually or via factory: `ApiException.fromResponse(response)`
- Implements `Exception` interface
- Exceptions caught at the UI layer in screen state (`LoginScreen._submit()`)
- Specific status codes handled with custom messages: 403 (unauthorized), 401 (invalid credentials), 400 (already_exists)
- Re-throw pattern used to propagate unexpected errors up the stack
- Error state stored in widget state: `_errorMessage` displayed to user
- JSON parsing failures silently caught and fallback to generic message: `catch (_) { ... }`
- Non-empty checks before parsing: `if (response.body.isNotEmpty)`

## Logging

- Current codebase does not use `print()` for debugging
- Console/debug output not visible in final product

## Comments

- Document public API behavior with doc comments (triple slash)
- Explain "why" rather than "what" in complex logic
- Mark edge cases and platform-specific behaviors
- Document deprecated patterns
- Use `///` for public API documentation on classes, functions
- Include examples and parameter descriptions when behavior is non-obvious
- Document factory constructors and notable parameters

## Function Design

- Use named parameters for multi-parameter functions
- Required parameters marked with `required` keyword
- Constructor parameters follow: `{super.key, required this.field}`
- Type annotations always explicit
- Functions return typed values (not `dynamic`)
- Futures used for async operations: `Future<String?>`, `Future<void>`
- Nullable returns marked with `?`: `String?`, `Future<Map<String, dynamic>?>`

## Module Design

- No barrel files (`index.dart` re-exports) used in current codebase
- Each file imports directly what it needs from other modules
- Single responsibility: each file contains one main class or tightly related set of classes
- Related functionality grouped in directories: `lib/api/`, `lib/features/auth/`, `lib/theme/`
- **API Layer** (`lib/api/`): HTTP client, authentication, token storage, exceptions
- **Features** (`lib/features/`): Screen components and feature-specific UI logic
- **Config** (`lib/config/`): Application-wide configuration (e.g., API base URL)
- **Theme** (`lib/theme/`): Theming and appearance logic
- **Navigation** (`lib/navigation/`): Navigation structure and root layout

<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->

## Architecture

## System Overview

```text

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

- **Authentication gating:** AuthGate wraps authenticated content, prevents unauthenticated access
- **Reactive state:** Uses ChangeNotifier (AuthSession, ThemeController) and ListenableBuilder for UI updates
- **Dependency injection:** Dependencies injected into main widget and propagated down (prop drilling)
- **Platform-aware:** Uses conditional imports for platform-specific HTTP client implementations
- **Token persistence:** Secure storage with automatic restoration on app start
- **Single HTTP client:** Centralized ApiClient handles all requests, auth, and error handling

## Layers

- Purpose: Display features, handle user interaction
- Location: `lib/features/*/` and `lib/navigation/`
- Contains: Feature screens (StatelessWidget/StatefulWidget), navigation widget
- Depends on: API layer (via dependency injection), theme
- Used by: Directly rendered by root app
- Purpose: HTTP communication, authentication state, token persistence
- Location: `lib/api/`
- Contains: ApiClient, AuthSession, PublicApi, TokenStorage
- Depends on: http package, flutter_secure_storage
- Used by: UI layer via dependency injection
- Purpose: App-wide configuration and theming
- Location: `lib/config/`, `lib/theme/`
- Contains: AppConfig, ThemeController, AppTheme
- Depends on: Nothing (core Flutter)
- Used by: Root app widget (CadenceApp)

## Data Flow

### Primary Request Path (Authenticated API Call)

### Theme Change Flow

### Auth Restoration on App Start

- **Auth state:** ChangeNotifier-based reactive (AuthSession)
- **Theme state:** ValueNotifier-based reactive (ThemeController)
- **UI state:** Widget state (LoginScreen, RootScaffold manage local form/navigation state)
- **Cross-layer communication:** Dependency injection + listener pattern

## Key Abstractions

- Purpose: Single source of truth for auth state and token
- Examples: `lib/api/auth_session.dart`
- Pattern: ChangeNotifier with three states (unknown, unauthenticated, authenticated)
- Purpose: Encapsulate HTTP communication, token injection, error handling
- Examples: `lib/api/api_client.dart`
- Pattern: Facade over http.Client, handles auth headers and 403 auto-logout
- Purpose: Type-safe, business-logic-aware API methods
- Examples: `lib/api/public_api.dart`
- Pattern: Wraps ApiClient, provides register() and login() methods
- Purpose: Encapsulate feature UI
- Examples: `lib/features/*/` (HomeScreen, BandsScreen, etc.)
- Pattern: StatelessWidget for simple screens, StatefulWidget for interactive ones

## Entry Points

- Location: `lib/main.dart`
- Triggers: App launch
- Responsibilities:
- Location: `lib/app.dart`
- Triggers: Called from main()
- Responsibilities:
- Location: `lib/features/auth/auth_gate.dart`
- Triggers: Rendered as home of MaterialApp
- Responsibilities:

## Architectural Constraints

- **Dependency injection pattern:** No service locators (like GetIt or Provider); dependencies passed via constructor. This makes testing easier but requires prop drilling from root.
- **Single HTTP client:** All API calls go through one ApiClient instance, ensuring consistent auth handling and error responses.
- **State persistence:** Only auth token is persisted; app state is not saved (stateless on restart).
- **Platform-specific code:** HTTP client creation uses conditional imports for web/native platforms; auth header attachment differs by platform.
- **No backend state management:** No local database or offline support; app assumes network access.
- **Authentication ceremony:** Token-based (cookie-like); server validates token on each request. 403 triggers immediate logout.

## Anti-Patterns

### Prop Drilling

### Manual Auth Header Management

### No Error Recovery

## Error Handling

- ApiClient throws ApiException for 4xx/5xx responses
- ApiException parses error response JSON for `code` and `message` fields
- LoginScreen catches ApiException, inspects statusCode/code, shows user-friendly message
- 403 responses trigger automatic signOut() in ApiClient before throwing

<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->

## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->

## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:

- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->

## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
