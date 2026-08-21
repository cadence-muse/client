# Codebase Structure

**Analysis Date:** 2026-08-21

## Directory Layout

```
cadence-client/
├── lib/                          # App source code (Dart)
│   ├── main.dart                 # Entry point, dependency setup
│   ├── app.dart                  # Root widget (CadenceApp)
│   ├── api/                      # HTTP client, auth, API methods
│   │   ├── api_client.dart       # HTTP wrapper, token injection, error handling
│   │   ├── auth_session.dart     # Auth state (ChangeNotifier)
│   │   ├── public_api.dart       # Login/register API methods
│   │   ├── token_storage.dart    # Secure token persistence
│   │   ├── api_exception.dart    # Exception type for API errors
│   │   ├── http_client_factory.dart     # Platform-agnostic factory
│   │   ├── http_client_factory_web.dart # Web HTTP client (uses BrowserClient)
│   │   ├── http_client_factory_io.dart  # Native HTTP client
│   │   ├── http_client_factory_stub.dart # Fallback implementation
│   │   └── publicapi.yml         # OpenAPI spec (reference only)
│   ├── config/                   # App configuration
│   │   └── app_config.dart       # API base URL (from build-time env vars)
│   ├── theme/                    # Theme management
│   │   ├── app_theme.dart        # Light/dark theme definitions
│   │   └── theme_controller.dart # Theme state (ValueNotifier)
│   ├── navigation/               # Navigation & routing
│   │   └── root_scaffold.dart    # Bottom navigation with IndexedStack
│   └── features/                 # Feature modules (screens & domain logic)
│       ├── auth/                 # Authentication feature
│       │   ├── auth_gate.dart    # Auth state gate widget
│       │   └── login_screen.dart # Login/signup UI
│       ├── home/                 # Home tab feature
│       │   └── home_screen.dart  # Home screen UI
│       ├── songs/                # Songs tab feature
│       │   └── songs_screen.dart # Songs screen UI
│       ├── bands/                # Bands tab feature
│       │   ├── band.dart         # Band model
│       │   └── bands_screen.dart # Bands screen UI
│       ├── profile/              # Profile tab feature
│       │   └── profile_screen.dart # Profile & settings UI
│       └── settings/             # Settings feature
│           └── settings_screen.dart # Settings screen UI
├── test/                         # Test files
│   └── widget_test.dart          # Widget tests, integration tests
├── android/                      # Android native scaffolding (generated)
├── ios/                          # iOS native scaffolding (generated)
├── web/                          # Web platform scaffolding (generated)
├── assets/                       # App assets
│   └── images/
│       └── logo.png
├── env/                          # Environment configuration files
│   └── config.example.json       # Example config (not secrets)
├── analysis_options.yaml         # Lint rules (extends flutter_lints)
├── pubspec.yaml                  # Dart dependencies & metadata
├── pubspec.lock                  # Locked dependency versions (generated)
├── .planning/                    # Codebase analysis
│   └── codebase/
│       ├── ARCHITECTURE.md       # Architecture overview
│       └── STRUCTURE.md          # This file
├── .github/                      # GitHub configuration
│   └── workflows/
│       ├── validate.yml          # CI: lint, test, analyze on push/PR
│       └── release.yml           # Release: Docker image + APK on semantic tags
├── .claude/                      # Claude Code settings
│   ├── settings.local.json       # Project-specific settings
│   └── CLAUDE.md                 # Project guidelines
├── .vscode/                      # VS Code settings
│   └── launch.json               # Debug configurations
├── .idea/                        # IDE settings (Android Studio, IntelliJ)
├── .metadata                     # Flutter project metadata (generated)
├── Dockerfile                    # Web deployment: nginx serving build/web
├── LICENSE                       # MIT License (2026 nightnoryu)
├── .gitignore                    # Git exclusions (Flutter standard)
└── README.md                     # Project documentation
```

## Directory Purposes

**`lib/`:**
- Purpose: All Dart application source code
- Contains: Widgets, business logic, API clients, configuration, themes
- Structure: Organized by functional layers (api/, config/, theme/, features/) and feature modules

**`lib/api/`:**
- Purpose: HTTP communication, authentication, token persistence
- Contains: ApiClient (HTTP wrapper), AuthSession (auth state), PublicApi (business methods), TokenStorage (persistence), platform-specific HTTP clients
- Key files: `api_client.dart`, `auth_session.dart`, `public_api.dart`, `token_storage.dart`

**`lib/config/`:**
- Purpose: App-wide configuration loaded at build/runtime
- Contains: API base URL and other static configuration
- Key files: `app_config.dart` (reads API_BASE_URL from environment)

**`lib/theme/`:**
- Purpose: Visual design (light/dark themes) and theme state management
- Contains: Theme definitions (AppTheme), theme state management (ThemeController)
- Key files: `app_theme.dart`, `theme_controller.dart`

**`lib/navigation/`:**
- Purpose: App navigation structure and routing
- Contains: Bottom navigation widget, screen management
- Key files: `root_scaffold.dart` (manages tab switching via IndexedStack)

**`lib/features/`:**
- Purpose: Feature-organized app functionality
- Structure: One subdirectory per major feature (auth, home, songs, bands, profile, settings)
- Each feature contains: Screens, models, and logic specific to that feature
- Files follow naming: `{feature}_screen.dart` for UI, `{model}.dart` for data classes

**`lib/features/auth/`:**
- Purpose: User authentication (login/signup)
- Key files: `auth_gate.dart` (guards authenticated content), `login_screen.dart` (auth UI)

**`lib/features/home/`:**
- Purpose: Home tab (currently placeholder)
- Key files: `home_screen.dart`

**`lib/features/songs/`:**
- Purpose: Songs/repertoire management tab (currently placeholder)
- Key files: `songs_screen.dart`

**`lib/features/bands/`:**
- Purpose: Band management tab
- Key files: `bands_screen.dart` (UI), `band.dart` (Band model)

**`lib/features/profile/`:**
- Purpose: User profile and app settings tab
- Key files: `profile_screen.dart`

**`lib/features/settings/`:**
- Purpose: App settings (currently separate from profile, but may merge)
- Key files: `settings_screen.dart`

**`test/`:**
- Purpose: Test files
- Contents: Widget tests, unit tests, integration tests
- Key files: `widget_test.dart` (example: navigation test with mocked auth)

**`android/`, `ios/`, `web/`:**
- Purpose: Platform-specific scaffolding (generated by `flutter create`)
- Rarely edited by hand; contain native code, build configs, and platform assets
- Android: Gradle build configuration, app signing, permissions
- iOS: Xcode project structure, native code, entitlements
- Web: HTML entry point, assets configuration, JavaScript interop

**`assets/`:**
- Purpose: App resources (images, fonts, etc.)
- Key files: `images/logo.png`

**`env/`:**
- Purpose: Environment configuration examples
- Files: `config.example.json` (safe to commit; shows structure, no secrets)
- Usage: Copy to `env/config.json` and populate with actual values via `flutter run --dart-define-from-file=`

**`.planning/codebase/`:**
- Purpose: Codebase analysis documentation
- Files: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md

**`.github/workflows/`:**
- Purpose: GitHub Actions CI/CD automation
- `validate.yml`: Runs tests and analysis on every push/PR to main (blocks merge on failure)
- `release.yml`: Builds and publishes Docker image + Android APK on semantic version tags (v*.*.*)
- Both workflows use Flutter 3.44.x stable channel (pinned)

## Key File Locations

**Entry Points:**
- `lib/main.dart`: App entry point, sets up dependencies and launches CadenceApp

**Root Widget:**
- `lib/app.dart`: CadenceApp root, theme management, AuthGate setup

**Authentication:**
- `lib/features/auth/auth_gate.dart`: Guards app with auth state
- `lib/features/auth/login_screen.dart`: Login/signup UI
- `lib/api/auth_session.dart`: Auth state management
- `lib/api/token_storage.dart`: Secure token persistence

**Navigation:**
- `lib/navigation/root_scaffold.dart`: Bottom navigation, tab management

**API Communication:**
- `lib/api/api_client.dart`: HTTP client with auth header injection
- `lib/api/public_api.dart`: Login/register API methods
- `lib/api/api_exception.dart`: Error handling

**Configuration:**
- `lib/config/app_config.dart`: API base URL configuration
- `pubspec.yaml`: Dependencies and app metadata
- `analysis_options.yaml`: Lint rules
- `.metadata`: Flutter project metadata (platform support, versions)

**Theming:**
- `lib/theme/app_theme.dart`: Theme definitions
- `lib/theme/theme_controller.dart`: Theme state

**Feature Screens:**
- `lib/features/auth/login_screen.dart`: Login/signup
- `lib/features/home/home_screen.dart`: Home tab
- `lib/features/songs/songs_screen.dart`: Songs tab
- `lib/features/bands/bands_screen.dart`: Bands tab
- `lib/features/profile/profile_screen.dart`: Profile/settings tab

**Testing:**
- `test/widget_test.dart`: Widget test examples

**Deployment:**
- `Dockerfile`: Web deployment — nginx alpine container serving `build/web/` on port 80
- `.github/workflows/validate.yml`: CI validation (tests + analysis)
- `.github/workflows/release.yml`: Release automation (Docker + APK)
- `LICENSE`: MIT license (copyright 2026 nightnoryu)

## Naming Conventions

**Files:**
- `{feature}_screen.dart`: Screen/page UI widgets
- `{entity}.dart`: Model classes (e.g., `band.dart` for Band model)
- `{name}_controller.dart`: State management classes (e.g., `theme_controller.dart`)
- `{feature}_gate.dart`: Auth/access control widgets (e.g., `auth_gate.dart`)

**Directories:**
- `lib/api/`: HTTP and authentication
- `lib/config/`: Configuration
- `lib/theme/`: Design and theming
- `lib/navigation/`: Routing and navigation
- `lib/features/{feature}/`: Feature-specific code
- `test/`: Tests (mirrors `lib/` structure expected, though currently minimal)

**Classes:**
- PascalCase: `CadenceApp`, `AuthSession`, `LoginScreen`
- Exception types: `ApiException`
- Enum types: `AuthStatus`, `_AuthMode`

**Variables/Functions:**
- camelCase: `authSession`, `themeController`, `signIn()`, `_selectedIndex`
- Private members: Leading underscore: `_token`, `_AuthMode`, `_authSession`, `_submit()`

**Dart-specific:**
- Mixin/abstract base classes: Use `abstract interface class` or `mixin`
- Extension methods: Extend existing types for utility functions
- Late initialization: Use `late` for non-nullable fields set after construction

## Where to Add New Code

**New Feature (e.g., Repertoire Management):**
- Primary code: `lib/features/{feature}/` - create new subdirectory
- Screen UI: `lib/features/{feature}/{feature}_screen.dart`
- Models: `lib/features/{feature}/{model}.dart`
- Add route to navigation: `lib/navigation/root_scaffold.dart` (add to screens list and NavigationBar destinations)
- Tests: `test/{feature}_test.dart` (or co-locate with feature)

**New API Endpoint:**
- Method: Add to `lib/api/public_api.dart` (high-level API wrapper)
- Implementation: Call `_client.send()` internally
- Error handling: Wrap with try/catch for ApiException, handle specific status codes
- Auth requirement: Set `requireAuth` parameter appropriately

**New Widget/Component:**
- Shared utilities: `lib/widgets/` (create if needed for reusable UI components)
- Feature-specific: Keep in `lib/features/{feature}/` subdirectory

**Configuration:**
- Build-time env vars: Update `lib/config/app_config.dart` with new String.fromEnvironment() constants
- Runtime config: Use AppConfig to access

**Theming:**
- Color schemes: `lib/theme/app_theme.dart` - update light/dark ThemeData
- Theme state: Extend `ThemeController` if need new reactive theme properties

**Authentication/Auth:**
- Token handling: Already centralized in `lib/api/auth_session.dart`
- Auth flow: Modify `lib/features/auth/login_screen.dart` for new steps
- Protected routes: Wrap with AuthGate or add auth checks in screen

**Tests:**
- Test files: Create in `test/` directory, mirror lib structure
- Mocking auth: Use `_FakeSecureStorage` pattern from `widget_test.dart`
- Widget tests: Use `WidgetTester` and `flutter_test` APIs

**CI/CD:**
- Add workflow: `.github/workflows/{name}.yml` using GitHub Actions syntax
- Validate workflow: Modify `.github/workflows/validate.yml` to add new checks (e.g., coverage, type checking)
- Release pipeline: Extend `.github/workflows/release.yml` for new platforms (e.g., iOS App Store, Windows Store)

## Special Directories

**`.dart_tool/`:**
- Purpose: Generated Dart toolchain files (plugin registry, package config)
- Generated: Yes
- Committed: No (in .gitignore)

**`build/`:**
- Purpose: Build outputs (compiled code, assets)
- Generated: Yes
- Committed: No (in .gitignore)
- Subdirectories: `build/web/` (web static files), `build/app/` (Android/iOS artifacts)

**`.idea/` and `.vscode/`:**
- Purpose: IDE configuration and settings
- Generated: Partially (some committed for project consistency)
- Committed: Partially (safe project settings, no personal overrides)

**`android/`, `ios/`, `web/`:**
- Purpose: Platform-specific scaffolding and native code
- Generated: Partially (created by `flutter create`, modified for platform-specific logic)
- Committed: Yes (part of source tree)

**`.github/`:**
- Purpose: GitHub Actions workflows and configuration
- Workflows: `.github/workflows/` contains CI/CD automation
- Committed: Yes (CI/CD is version-controlled)

---

*Structure analysis: 2026-08-21*
