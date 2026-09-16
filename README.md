# Cadence Client

The Flutter application for [Cadence](https://github.com/cadence-muse), a shared repertoire manager for musical bands.
It targets Android, iOS, and the web, with read-only offline access on mobile.

## 🎯 Responsibilities

- Authentication and secure session-token storage
- Band membership and ownership workflows
- Track catalogs, search, details, and editing
- Setlist planning, ordering, and performance views
- Cached reads for use with an unreliable or missing connection
- Metronome, localization, light and dark themes

## 🏗️ Architecture

```text
lib/features       screens and feature-specific widgets
lib/providers      Riverpod state, API orchestration, and cache coordination
lib/api            HTTP client, public API facade, and token storage
lib/cache          Hive-backed read cache
lib/navigation     application navigation
lib/config         build-time configuration
lib/theme          shared visual theme
lib/l10n           localization sources
```

Riverpod providers connect the interface to `PublicApi` and expose asynchronous feature state.
All HTTP traffic passes through one `ApiClient`, which attaches the current session token and
handles authentication failures. Successful reads are stored in Hive on mobile so previously loaded
profile, homepage, band, track, and setlist data remains available offline. Mutations require a connection.

## 🛠️ Local development

### Prerequisites

- Flutter 3.44 or a compatible stable release
- Dart 3.12.2 or newer
- An Android SDK, Xcode, or a supported web browser for the chosen target
- A running [Cadence API](https://github.com/cadence-muse/cadence)

```shell
git clone https://github.com/cadence-muse/client.git
cd client
flutter pub get
cp env/config.example.json env/config.json
flutter run --dart-define-from-file=env/config.json
```

For web development, use the port allowed by the backend's default CORS configuration:

```shell
flutter run -d chrome --web-port 33721 \
  --dart-define-from-file=env/config.json
```

## 🔌 Working with the API

The client consumes the public contract mirrored at [`lib/api/publicapi.yml`](lib/api/publicapi.yml).
Request methods live in `lib/api/public_api.dart`; shared transport, token injection, and API errors live in `lib/api/`.

When the server contract changes:

1. Update the mirrored OpenAPI file from the backend repository.
2. Adjust `PublicApi` methods and affected providers.
3. Cover response parsing and feature behavior with focused tests.
4. Run `flutter test` and `flutter analyze`.

The `Authorization` header contains the session token returned by login. Native builds store it with
`flutter_secure_storage`. A rejected session signs the user out through the shared authentication provider.

## ⚙️ Configuration

`API_BASE_URL` is the only application setting. Supply it as a Dart define or through a JSON file:

```shell
flutter run --dart-define=API_BASE_URL=http://localhost:8080
flutter build web --dart-define-from-file=env/config.web.json
flutter build apk --release --dart-define-from-file=env/config.apk.json
```

Use `env/config.example.json` as the template for local files. An empty base URL is valid for the deployed web build
when the API is served from the same origin.

## 🧪 Testing and code generation

```shell
flutter test
flutter analyze
dart run build_runner build --delete-conflicting-outputs
```

Tests cover the API layer, cache, providers, and feature widgets. Riverpod-generated `*.g.dart` files
should be regenerated after changing annotated providers.

## 📦 Builds

The web release is a static Flutter build served by Nginx. Android releases are APKs.
The repository's release workflow builds both artifacts from the checked-in environment files.

```shell
flutter build web --dart-define-from-file=env/config.web.json
flutter build apk --release --dart-define-from-file=env/config.apk.json
```

## 📜 License

Distributed under the [MIT License](LICENSE).
