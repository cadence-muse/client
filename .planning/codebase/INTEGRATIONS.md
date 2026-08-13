# External Integrations

**Analysis Date:** 2026-08-13

## APIs & External Services

**Cadence Backend API:**
- Service: Custom REST API (OpenAPI spec at `lib/api/publicapi.yml`)
- What it's used for: User authentication, registration, band/song data management
  - SDK/Client: Dart `http` package (1.6.0)
  - Base URL: Configurable via `API_BASE_URL` environment variable
  - Default: `http://localhost:8080`
  - Implementation: `lib/api/api_client.dart`

## Data Storage

**Databases:**
- Type: Remote via API only
- Connection: HTTP REST calls to backend
- Client: `ApiClient` in `lib/api/api_client.dart`
- No local database (SQLite, etc.) currently implemented

**Secure Token Storage:**
- Service: flutter_secure_storage (native platform secure storage)
- Purpose: Persisting user authentication token between app launches
- Storage class: `TokenStorage` in `lib/api/token_storage.dart`
- Token key: `auth_token`

**File Storage:**
- Type: Local filesystem only
- Assets location: `assets/images/` (app icons, logos)

**Caching:**
- Type: None currently implemented
- Note: Session token cached in memory during app runtime

## Authentication & Identity

**Auth Provider:**
- Type: Custom token-based authentication
- Implementation: Cookie and Bearer token via HTTP headers
- Cookie name: `cadencesession`
- Token storage: Secure storage via flutter_secure_storage
- Auth session class: `AuthSession` in `lib/api/auth_session.dart`

**Auth Flow:**
1. User registration: POST `/api/register` (username + password)
2. User login: POST `/api/login` (username + password) → returns token
3. Authenticated requests: Token passed as `Cookie: cadencesession=<token>` header (native) or browser credentials (web)
4. Session validation: 403 response triggers automatic sign out

**Platform-Specific Behavior:**
- Web: Browser handles cookie jar automatically with `credentials: 'include'`
- Native (iOS/Android): Token explicitly forwarded as `Cookie` header by `ApiClient`

## Monitoring & Observability

**Error Tracking:**
- Type: None currently implemented
- Error handling: `ApiException` class in `lib/api/api_exception.dart`
- HTTP errors (4xx, 5xx) throw exceptions

**Logs:**
- Type: Console logging only (via Flutter's print/debugPrint)
- No external logging service integration

## CI/CD & Deployment

**Hosting:**
- Multiple targets: iOS App Store, Google Play Store, Web
- Platform-specific builds via Flutter CLI

**CI Pipeline:**
- Type: None configured
- Manual build via `flutter build apk`, `flutter build ios`, `flutter build web`

## Environment Configuration

**Required env vars:**
- `API_BASE_URL`: Backend API endpoint
  - Format: Full URL (e.g., `http://localhost:8080`, `https://api.cadence.app`)
  - Default: `http://localhost:8080`
  - Method: Set via `--dart-define=API_BASE_URL=<url>` or config file

**Optional env vars:**
- None currently documented

**Secrets location:**
- Configuration: `env/config.example.json`
- Example format:
  ```json
  {
    "API_BASE_URL": "http://localhost:8080"
  }
  ```
- Usage: `flutter run --dart-define-from-file=env/config.json`
- Note: Auth token stored in platform-specific secure storage, not in config files

## Webhooks & Callbacks

**Incoming:**
- None implemented

**Outgoing:**
- None implemented

---

*Integration audit: 2026-08-13*
