# Technology Stack

**Analysis Date:** 2026-08-16

## Languages

**Primary:**
- Dart 3.12.2+ - Core app language, cross-platform compilation
- Kotlin - Android native code (platform scaffolding)
- Swift - iOS native code (platform scaffolding)

**Secondary:**
- JavaScript - Web build target

## Runtime

**Environment:**
- Flutter SDK (latest stable)
- Dart 3.12.2+ via Flutter SDK
- Android Runtime (APK build target)
- iOS Runtime (iPhone/iPad)
- Web browser (web build target)

**Package Manager:**
- Pub (Dart package manager)
- Lockfile: `pubspec.lock` present
- Dependency resolution: `pubspec.yaml`

## Frameworks

**Core:**
- Flutter - UI framework for iOS, Android, and web
  - Material Design widgets used throughout
  - Navigation via custom `root_scaffold.dart`

**Testing:**
- flutter_test - Built-in Flutter testing framework
- Test runner via `flutter test` command

**Build/Dev:**
- flutter_lints 6.0.0 - Linting rules (extends `package:flutter_lints/flutter.yaml`)
- Analysis runner via `flutter analyze`

## Key Dependencies

**Critical:**
- http 1.6.0 - HTTP client for REST API communication (`lib/api/api_client.dart`)
- flutter_secure_storage 11.0.0 - Secure token persistence on native platforms
- flutter_secure_storage_platform_interface 2.0.3 - Platform abstraction layer

**UI:**
- cupertino_icons 1.0.8 - iOS-style icon font

## Configuration

**Environment:**
- Dart define variables (`--dart-define=` flag)
- Configuration file: `env/config.example.json`
- Example: `flutter run --dart-define-from-file=env/config.json`
- AppConfig located at: `lib/config/app_config.dart`

**Build:**
- `analysis_options.yaml` - Dart analyzer configuration (includes `package:flutter_lints/flutter.yaml`)
- Android: `android/build.gradle.kts`, `android/app/build.gradle.kts`
- iOS: `ios/Runner.xcodeproj`, `ios/Runner.xcworkspace`
- Web: Flutter web build tooling (auto-configured)

## Platform Requirements

**Development:**
- Flutter SDK installed with Dart 3.12.2+
- For Android: Android Studio or command-line Android SDK
- For iOS: Xcode and Apple development tools (macOS)
- For web: No additional requirements beyond Flutter

**Production:**
- Android deployment: Google Play Store (APK/AAB)
- iOS deployment: Apple App Store (IPA)
- Web deployment: Static web host or Flutter web server

## CI/CD

**Pipelines:**
- Validation: `.github/workflows/validate.yml` - Runs on push/PR to main
- Release: `.github/workflows/release.yml` - Runs on version tags (v*.*.*)

**Validate Workflow (`.github/workflows/validate.yml`):**
- **Trigger:** Push to main branch, pull requests to main
- **Runner:** ubuntu-latest
- **Flutter version:** 3.44.x (pinned, stable channel)
- **Jobs:**
  - Checkout code
  - Setup Flutter SDK with caching enabled
  - Install dependencies: `flutter pub get`
  - Run unit tests: `flutter test`
  - Run static analysis: `flutter analyze`
- **Caching:** GitHub Actions cache for Flutter SDK enabled

**Release Workflow (`.github/workflows/release.yml`):**
- **Trigger:** Git tags matching `v*.*.*` pattern
- **Runner:** ubuntu-latest
- **Flutter version:** 3.44.x (pinned, stable channel)
- **Permissions:** contents:write, packages:write
- **Registry:** GitHub Container Registry (GHCR) at `ghcr.io`

  **Job: deploy-docker**
  - Checkout code
  - Setup Flutter SDK with caching
  - Log in to GHCR using `${{ secrets.GITHUB_TOKEN }}`
  - Extract Docker metadata (tags: semver pattern + latest)
  - Set up Docker buildx
  - Install dependencies: `flutter pub get`
  - Build web static files: `flutter build web --dart-define=API_BASE_URL=`
  - Build and push Docker image
    - Uses `docker/build-push-action@v6`
    - Context: repository root
    - Caching: GitHub Actions cache for Docker (mode=max)
    - Publishes to: `ghcr.io/${{ github.repository }}`

  **Job: release-apk**
  - Checkout code
  - Setup Flutter SDK with caching
  - Setup Java: version 17 (Zulu distribution) for Android build
  - Install dependencies: `flutter pub get`
  - Build APK (release mode): `flutter build apk --release --dart-define=API_BASE_URL=https://cadence.app`
  - Calculate SHA256 hash: stored in `app-release.apk.sha256.txt`
  - Create GitHub Release using `gh release create`
    - Attaches APK and SHA256 checksum files
    - Generates release notes automatically
    - Upload location: `.planning/codebase/STACK.md`

**Build Targets:**
- Android: APK (release) via `flutter build apk`
- Web: Static assets via `flutter build web`
- Docker: Web build containerized and published to GHCR
- iOS: Not automated in CI/CD (requires macOS runner and signing certificates)

**Environment Variables:**
- `API_BASE_URL` - Passed at build time via `--dart-define`
  - Web/Docker build: empty (configuration-agnostic)
  - APK build: `https://cadence.app`

**Actions Used:**
- `actions/checkout@v6` - Code checkout
- `subosito/flutter-action@v2` - Flutter SDK setup
- `actions/setup-java@v4` - Java environment for Android build
- `docker/login-action@v3` - GHCR authentication
- `docker/metadata-action@v5` - Docker image metadata and tags
- `docker/setup-buildx-action@v3` - Docker buildx setup
- `docker/build-push-action@v6` - Docker build and push

---

<!-- refreshed: 2026-08-16 -->

*Stack analysis: 2026-08-16*
