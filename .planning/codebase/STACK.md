# Technology Stack

**Analysis Date:** 2026-08-13

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

---

*Stack analysis: 2026-08-13*
