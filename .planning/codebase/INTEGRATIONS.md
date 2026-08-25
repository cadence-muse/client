# External Integrations

**Analysis Date:** 2026-08-25

## APIs & External Services

**Cadence Public API:**
- Service: Custom REST API (backend service)
- Purpose: Core business operations (auth, band/track/setlist CRUD, user profile)
- SDK/Client: `http` 1.6.0 package
- Base URL: Configurable via `API_BASE_URL` dart-define (defaults to `http://localhost:8080`)
  - Set at build time: `flutter run --dart-define=API_BASE_URL=https://api.example.com`
  - Or: `flutter run --dart-define-from-file=env/config.json`

**API Endpoints Summary:**
- **Auth:** POST `/api/register`, POST `/api/login`, POST `/api/logout`, POST `/api/me/password`
- **User:** GET `/api/me` (profile), POST `/api/me/password` (change password)
- **Bands:** GET `/api/band/list`, GET/POST/PUT/DELETE `/api/band/{id}`, POST `/api/band/join`, POST/DELETE member operations, POST `/api/band/{id}/rotate-invite-code`, POST `/api/band/{id}/transfer-ownership`
- **Tracks:** GET/POST/PUT/DELETE `/api/band/{id}/track/{id}`, GET `/api/band/{id}/track/list` with search support, POST `/api/track/list` (user's all tracks)
- **Setlists:** GET/POST/PUT/DELETE `/api/band/{id}/setlist/{id}`, GET `/api/band/{id}/setlist/list`, POST/DELETE setlist tracks, PUT reorder, POST `/api/setlist/list` (user's all setlists)

**Full API Contract:**
- Location: `lib/api/publicapi.yml` (OpenAPI 3.0.0 specification)
- Authentication: Session-based token auth via `Authorization` header (sessionAuth in spec)
- Response format: JSON
- Error responses: Include `code` and `message` fields (parsed in `lib/api/api_exception.dart`)

**HTTP Client Implementation:**
- Location: `lib/api/api_client.dart`
- Features:
  - Automatic token attachment to authenticated requests
  - HTTP method abstraction (GET, POST, PUT, DELETE)
  - Query parameter and JSON body support
  - 403 response handling: automatically triggers `signOut()` on session expiry
  - 4xx/5xx error parsing: converts to `ApiException` with statusCode, code, message
- Platform-specific HTTP client factory: `lib/api/http_client_factory*.dart`
  - `http_client_factory_io.dart` - Android/iOS native (uses `dart:io`)
  - `http_client_factory_web.dart` - Web platform (uses `dart:html` indirectly via http package)
  - `http_client_factory_stub.dart` - Stub for testing/analysis

## Data Storage

**Local Databases:**
- **Hive** (file-based key-value store)
  - Package: `hive` 2.2.3, `hive_flutter` 1.1.0
  - Purpose: Offline read-only cache (last-fetched API responses)
  - Initialization: `Hive.initFlutter()` in `lib/main.dart`, then `CacheService.initialize()` opens boxes
  - Cache structure: Five Hive boxes (one per endpoint category)
    - `profileBox` - User profile data
    - `homepageBox` - Homepage data
    - `bandsBox` - Band list and detail data
    - `tracksBox` - Band tracks and user tracks
    - `setlistsBox` - Band setlists and user setlists
  - Cache format: Raw JSON response bodies (`Map<String, dynamic>`) with metadata
    - Each cached entry includes: `{data: {...}, syncedAt: ISO8601_string}`
  - Implementation: `lib/cache/cache_service.dart`
    - One-box-per-endpoint design per spec (D-02)
    - Deep type conversion for Hive's untyped `Map<dynamic, dynamic>` returns
    - Read-only: no offline write queue, no conflict resolution
  - Access: Via `cacheServiceProvider` (Riverpod provider in `lib/providers/*_provider.dart`)
  - Cleared on logout: `CacheService.clearAll()` called from `AuthSession.signOut()`
  - Platform-specific: Stored in device's default app data directory (Android internal storage, iOS Documents)

**File Storage:**
- None beyond Hive; no user file uploads or downloads in this milestone

**Secure Credential Storage:**
- **flutter_secure_storage** 11.0.0
  - Purpose: Secure auth token persistence across app restarts
  - Android: Uses Android KeyStore encryption
  - iOS: Uses iOS Keychain
  - Implementation: `lib/api/token_storage.dart`
    - Single key: `'auth_token'`
    - Methods: `read()`, `write(token)`, `delete()`
  - Access: Via `tokenStorageProvider` Riverpod provider

**Caching:**
- **Offline Read Cache (Hive)** - Last-fetched endpoint responses cached locally for offline access
  - Strategy: Cache-aside (app tries network first, falls back to cache on error)
  - Implementation: Each feature provider (e.g., `bandsProvider`, `tracksProvider`) checks cache before/after network calls
  - Example: `lib/providers/bands_provider.dart` caches band list and detail on successful fetch
  - Invalidation: Manual on auth logout, or implicit (always re-fetch on network success)

## Authentication & Identity

**Auth Provider:**
- Custom token-based authentication (no OAuth/OIDC)
- Implementation: `lib/providers/auth_provider.dart` + `lib/api/public_api.dart`
- Flow:
  1. User registers: `PublicApi.register(username, password)` → receives user ID
  2. User logs in: `PublicApi.login(username, password)` → receives session token
  3. Token persisted: `TokenStorage.write(token)` to secure storage
  4. Token restored on startup: `AuthSession.build()` reads from storage
  5. All API calls: Token attached via `Authorization` header in `ApiClient`
  6. Logout: `AuthSession.signOut()` → invalidates server session + clears local storage + clears cache
  7. Session expiry: 403 response triggers automatic `signOut()`

**Token Persistence:**
- Secure storage across app restarts via `flutter_secure_storage`
- Reentrancy guard in `AuthSession.signOut()` prevents recursive logout on nested 403 errors

**Auth State:**
- Managed by `authSessionProvider` (Riverpod provider)
- State: `Future<String?>` (token value or null if unauthenticated)
- Watcher: `AuthGate` widget decides to show LoginScreen or authenticated content based on state

## Monitoring & Observability

**Error Tracking:**
- No dedicated error tracking service integrated (Sentry, Crashlytics, etc.)
- Local error handling: Exceptions caught at UI layer in screen state
- Error parsing: `ApiException.fromResponse(response)` extracts statusCode, code, message from JSON

**Logs:**
- No structured logging library (e.g., logger, Sentry)
- Print statements avoided per project conventions
- Debug output not visible in final product

**Network Connectivity:**
- **connectivity_plus** 7.3.1
  - Purpose: Detect online/offline state for cache fallback strategy
  - Implementation: `lib/providers/connectivity_provider.dart`
  - Usage: Providers check connectivity before attempting network calls; fallback to cache on offline

## CI/CD & Deployment

**Hosting:**
- Backend API: Configured per environment via `API_BASE_URL` dart-define
- App delivery: Google Play Store (Android), Apple App Store (iOS), web (static host or server)

**CI Pipeline:**
- Not detected in codebase (no `.github/workflows`, `.gitlab-ci.yml`, etc.)
- Implied: Manual builds via `flutter build apk`, `flutter build ios`, `flutter build web`

## Environment Configuration

**Required env vars:**
- `API_BASE_URL` - REST API base URL (e.g., `https://api.cadence.app`)
  - Defaults to `http://localhost:8080` if not provided
  - Set via: `--dart-define=API_BASE_URL=...` or `--dart-define-from-file=env/config.json`

**Secrets location:**
- Configuration example: `env/config.example.json` (checked in; never contains real secrets)
- Real configuration: Passed at build time, not stored in repo
- Auth tokens: Persisted in secure storage at runtime, never checked in

**No .env file:**
- Dart/Flutter doesn't use .env files; configuration is via dart-define at build time

## Webhooks & Callbacks

**Incoming:**
- None defined; API is purely request-response

**Outgoing:**
- None defined; no background sync or push notifications in this milestone

## Network Behavior

**Request Handling:**
- All API calls go through single `ApiClient` instance (injected via Riverpod)
- Automatic bearer token attachment: `Authorization: [token]`
- JSON request/response bodies
- Query parameters support (e.g., `bandIdFilter` in track/setlist list endpoints)
- Retry policy: None built-in; failures propagate to caller

**Error Handling:**
- HTTP 4xx/5xx responses: Thrown as `ApiException` with parsed error code and message
- HTTP 403: Interpreted as session expiry; triggers automatic `signOut()` before throwing
- Network errors (timeout, connection refused): Propagated as exceptions; caught at UI layer
- Empty response bodies handled gracefully (returns `null` from `ApiClient.send`)

**Offline Fallback:**
- Cache-aside strategy: Hive cache checked on network failure
- Read-only offline mode: Users can view last-synced data offline
- No offline write queue: Mutations require network connectivity

---

*Integration audit: 2026-08-25*
