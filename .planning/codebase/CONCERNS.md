# Codebase Concerns

**Analysis Date:** 2026-08-25

## Tech Debt

**Cache-Write Race in Refresh Cycles (CR-01):**
- Issue: Local mutations (e.g., `removeFromList()`, `updateFields()`) correctly guard in-memory `state` with a `_version` counter to prevent stale background refreshes from reverting them. However, `_fetchAndCache()` writes to the persistent cache **unconditionally** before `_doRefresh()` checks the version guard. A slower background refresh that started before a mutation can therefore overwrite the mutation's cache write with stale data, defeating offline-cache-trust guarantees.
- Files: `lib/providers/tracks_provider.dart` (lines 68-72, 83-103), `lib/providers/setlists_provider.dart` (lines 77-83, 118-140), `lib/providers/bands_provider.dart` (lines 77-84, 96-140)
- Impact: App UI shows correct state (in-memory), but if force-closed offline or if in-memory state is lost (via `autoDispose`), persisted cache serves stale data. Reappearance of deleted items or reverted edits on app restart.
- Fix approach: Gate the `cacheService.writeX()` call on the same version check as the `state` commit. Move version check before cache write, or restructure to make network call + cache commit + state commit atomic. Add regression tests asserting `cacheService.readX()` (not just `state`) after the WR-02 race for list + detail providers.

**Stale Band-Filter Selection Crashes DropdownButton (CR-02):**
- Issue: `selectedBandIdFilterProvider` and `selectedSetlistBandIdFilterProvider` persist a chosen `bandId` indefinitely. When the filtered band disappears from the bands list (user leaves, band deleted, or ownership transferred elsewhere), `DropdownButton` is given a `value` that has no matching item, triggering constructor assertion: "There should be exactly one item with [DropdownButton]'s value". Hard crash in debug/profile/test builds.
- Files: `lib/features/songs/tracks_screen.dart` (lines 65-86), `lib/features/setlists/setlists_screen.dart` (lines 62-89), `lib/providers/tracks_provider.dart` (lines 270-284, `SelectedBandIdFilter`), `lib/providers/setlists_provider.dart` (lines 301-323, `SelectedSetlistBandIdFilter`)
- Impact: User leaves band A while it's the active filter → hard crash on returning to Tracks/Setlists tab. Reproduction: join bands A+B, filter to A, leave A from another screen, return to Tracks tab → crash.
- Fix approach: Clamp the persisted filter value against the live bands list at render time (not just at set time). When `selectedBandIdFilter` no longer exists in the current bands list, fall back to `null` ("All bands"). Add regression test exercising "filtered band disappears" scenario.

## Known Bugs

**Copy Invite Code Incorrectly Gated Behind Offline Status (WR-01):**
- Symptoms: Copy button is disabled when offline, even though copying to clipboard is a synchronous local operation with no network dependency. Regression from pre-Phase-8 behavior where Copy was always enabled. Contradicts both `08-CONTEXT.md` D-07 decision ("Copy stays visible to everyone as today") and project Core Value ("band member can open app without signal... and still see... setlist").
- Files: `lib/features/bands/band_detail_screen.dart` (lines 248-256)
- Trigger: Go offline, navigate to band detail, attempt to copy invite code — button is disabled and shows tooltip "Requires connection".
- Workaround: Go online before copying invite code.
- Fix approach: Un-gate the Copy button's `onPressed` from `isOnline`. Change `onPressed: isOnline ? () => _copyInviteCode(...) : null` to `onPressed: () => _copyInviteCode(...)`. Keep visual Tooltip/IconButton upgrade; restore pre-Phase-8 unconditional availability for clipboard operations.

## Test Coverage Gaps

**Cache-Write Race Untested in WR-02 Regression Tests:**
- What's not tested: Every WR-02 test asserts in-memory `state` correctness after a mutation race with a slow refresh, but none verify that `cacheService.readX()` remains correct. Cache corruption is therefore undetected by existing tests.
- Files: `test/providers/tracks_provider_test.dart`, `test/providers/setlists_provider_test.dart`, `test/providers/bands_provider_test.dart` (WR-02 test sections)
- Risk: Stale cache regression can ship unnoticed; users experience data reappearance on app restart after mutations.
- Priority: High — add cache read assertions to existing WR-02 tests for at least one list provider and one detail provider.

**Band Filter Disappearance Scenario Unguarded:**
- What's not tested: Leaving/deleting/losing ownership of the currently filtered band while on Tracks/Setlists tab, then returning to the tab (or viewing immediately).
- Files: `test/features/songs/tracks_screen_test.dart`, `test/features/setlists/setlists_screen_test.dart`
- Risk: Hard crash in debug/test builds; undefined dropdown state in release builds.
- Priority: High — add test exercising "filtered band disappears from list" scenario for both screens.

## Fragile Areas

**Provider Refresh Deduplication with Forced Resync (Setlist/Tracks/Bands Providers):**
- Files: `lib/providers/setlists_provider.dart` (lines 102-117, `refresh()` with `force` parameter), `lib/providers/tracks_provider.dart`, `lib/providers/bands_provider.dart`
- Why fragile: Complex state machine with `_inFlightRefresh` Future reuse and `_refreshPending` flag managing overlapping calls. Forced (`force: true`) resync must queue a second refresh if one is already in flight, but a plain refresh tap should dedupe. Any misstep (e.g., forgetting to check `_inFlightRefresh` before setting `_refreshPending`, or reordering the `do-while` loop) silently breaks mutation-resync guarantees documented in extensive comments (WR-01, WR-02). Not easily caught by tests because timing-dependent race conditions are fragile under different execution speeds.
- Safe modification: Document the exact call sequence and intent before changing. Add regression tests specifically exercising rapid `refresh()` calls interleaved with `refresh(force: true)` calls. Avoid "optimization" attempts to simplify the dedup logic without confirming the full state machine behavior first.
- Test coverage: Regression tests exist in provider tests but exercise only the happy path. Missing: explicit tests for the race windows documented in comment blocks (e.g., "if refresh is already in flight when a forced call arrives...").

**Riverpod Async Mutation Ordering (State Commit Timing):**
- Files: All provider classes with mutation methods (`BandsListData.setBands()`, `TrackListData.removeFromList()`, `SetlistDetailData.reorderTracks()`, etc.)
- Why fragile: The `_version++` counter must be incremented **before** `state = AsyncData(...)` to guard downstream code. If reversed, in-memory state update appears to refresh before the version counter is bumped, allowing a concurrent `_doRefresh()` to observe a stale version but see a newer state. This must be done identically in every mutation method across 6+ provider classes — a copy-paste bug waiting to happen if any instance is missed. `flutter analyze` doesn't catch this; only integration tests and code review catch version-ordering errors.
- Safe modification: Any new mutation method must follow the exact pattern used in existing methods: `_version++` first, then `state = AsyncData(...)`, then cache write via `unawaited()`. Treat as a cargo-cult pattern (do exactly as written, not as understood), and document via an example in each provider's header comment.
- Test coverage: Existing WR-02 tests verify state correctness but don't specifically assert "version was bumped before state change" — they only test the end result. Fragility: a test-pass doesn't guarantee the mutation code is correct.

## Scaling Limits

**Setlist Track Limit (100 Track Cap):**
- Current capacity: Reorder operations are capped at 100 tracks per setlist (server-side `ReorderSetlistTracksRequestBody`'s `trackIds` constraint per `publicapi.yml`).
- Limit: Setlists with more than 100 tracks cannot be reordered via the client UI — reorder attempts deterministically fail with "Can't reorder — this setlist has more than 100 tracks" (see `setlist_detail_screen.dart`, line 134-145, `_maxSetlistTracks` guard).
- Scaling path: Server-side limitation. If future versions support larger setlists, the client-side guard (hardcoded `_maxSetlistTracks = 100`) must be updated in tandem. Consider making this a server-side error response (don't send invalid payloads) rather than a client-side preventive check, so the limit can change server-side without client updates.

## Missing Critical Features

**Backend searchQuery Field Not Implemented:**
- Problem: `publicapi.yml` spec defines `searchQuery` as a query parameter on `ListBandTracks` endpoint (SETL-12, D-03 addition). Client sends it (see `lib/api/public_api.dart`, lines 168-185), but server ignores it and always returns the full unfiltered list. Setlist track picker (Phase 10) degrades to offline substring filtering until backend support ships.
- Blocks: Efficient server-side search on setlist track picker; client currently filters ~all tracks offline, which does not scale well for bands with hundreds of tracks.

**Backend currentPassword Validation:**
- Problem: `publicapi.yml` specifies that `changePassword` expects `currentPassword` in the request body, but backend validation of it may land separately. On wrong `currentPassword`, server responds with `400` and `ErrorCode.invalid_input` (never `401`). Client code (see `lib/api/public_api.dart`, lines 51-68) documents this assumption and branches on `statusCode == 400 && code == 'invalid_input'`.
- Blocks: Full password-change flow without additional backend landing.

## Dependencies at Risk

**No Critical Dependencies at Risk:**
- All major dependencies (Flutter, Riverpod, Hive, http, connectivity_plus) are on stable versions with active maintenance and regular updates. No known CVEs or EOL dates.
- Note: `pubspec.yaml` uses range constraints (e.g., `^1.6.0`, `^2.6.1`) which allow automatic patch + minor version updates. Consider pinning major.minor if you require stability across team builds (see `.pubspec.lock`).

## Security Considerations

**Token Persistence via flutter_secure_storage:**
- Risk: Session tokens are persisted securely on-device via `flutter_secure_storage` (see `lib/api/token_storage.dart`). If device is compromised (rooted, jailbroken, or physically accessed), tokens can be extracted.
- Files: `lib/api/token_storage.dart`, `lib/providers/auth_provider.dart`
- Current mitigation: Uses platform-native secure storage (Keychain on iOS, Keystore on Android). Tokens are never logged or exposed in plaintext. 403 responses trigger immediate `signOut()`.
- Recommendations: (1) Add token expiration / refresh token support if the backend implements it (see `publicapi.yml` for session schema). (2) Consider implementing device-binding (e.g., check device ID, IP, or cert pinning on critical endpoints) to reduce token reuse risk if stolen. (3) Document token revocation procedure (user should call `signOut()` if device is lost).

**No Validation of Backend Responses:**
- Risk: Client accepts and uses all fields from API responses without schema validation. If backend is compromised or returns malformed data, the app will accept it. Example: `bandAsync.valueOrNull?['name'] as String?` assumes the response matches the expected shape but does no runtime validation.
- Files: All provider classes that call `publicApiProvider` methods (e.g., `lib/providers/bands_provider.dart`, `lib/providers/tracks_provider.dart`)
- Current mitigation: TypeScript-like compile-time Dart typing catches obvious shape mismatches. `publicapi.yml` serves as a schema reference. Runtime cast failures throw exceptions caught at the UI layer.
- Recommendations: (1) Consider adding a lightweight schema validator (e.g., generated from `publicapi.yml` or using a package like `json_schema`) to catch backend drift early. (2) Log/alert on response shape mismatches to detect compromised or misconfigured backend.

**Offline Data Visibility Without Encryption:**
- Risk: Cached data (bands, tracks, setlists) is persisted via Hive to unencrypted files on-device. On a compromised device, an attacker can read the cache files directly without needing the token.
- Files: `lib/cache/cache_service.dart`, Hive box initialization in `lib/main.dart`
- Current mitigation: `flutter_secure_storage` for tokens only; cache is not encrypted. Device physical security and OS-level file permissions are the primary defense.
- Recommendations: (1) If band/track data is sensitive (private repertoires), consider encrypting Hive boxes (Hive supports encryption via `encryptionCipher`). (2) Clearly document that cached data is visible to any app/user with file-system access on the device. (3) Offer a "Clear Cache" option in settings (currently missing).

---

*Concerns audit: 2026-08-25*
