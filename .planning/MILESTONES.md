# Milestones

## v1.0 MVP (Shipped: 2026-08-17)

**Phases completed:** 5 phases, 23 plans, 46 tasks

**Key accomplishments:**

- Migrated the app shell off ChangeNotifier/ValueNotifier onto codegen'd Riverpod Notifiers, stood up a Hive-backed cache-store pattern, and proved both end-to-end on a real GET /api/me-backed Profile screen.
- Added `ProviderContainer`-based unit tests for `AuthSession` and `ThemeController`, including a spy-verified test of the cache-clear-on-signOut privacy mitigation and an automated regression guard proving no `ChangeNotifier`/`ValueNotifier` remains under `lib/`.
- Wired the Home tab to real `GET /api/homepage` data using the exact cache-first Riverpod+Hive pattern proven for Profile in 01-01, adding a second per-endpoint Hive box (`homepageBox`) and completing OFFL-01 test coverage for both Phase 1 endpoints.
- GET /api/band/list wired end-to-end — PublicApi method, new bandsBox Hive cache, BandsListData cache-first Riverpod provider, and a real BandsScreen — replacing the hardcoded "B.A.T.H." mock list
- GET /api/band/{bandId} wired end-to-end — PublicApi method, per-band-keyed entries in the existing bandsBox, the project's first family Riverpod provider (BandDetailData), and a real BandDetailScreen with working copy-to-clipboard invite code
- Single-FAB Create/Join entry point wired end-to-end — `POST /api/band` via a new full-screen CreateBandScreen and `POST /api/band/join` via a JoinBandDialog that resolves the joined band's id through a client-side list-diff, since the join endpoint returns no response body
- PUT /api/band/{bandId} wired end-to-end via EditBandScreen — a pre-filled, non-owner-gated rename form that merges the submitted name straight into `BandDetailData`'s cache instead of trusting a (nonexistent) server response body.
- Owner-gated Delete band (type-to-confirm), self-Leave, and owner-Remove-member all wired end-to-end onto `BandDetailScreen`, sharing a single `PublicApi.removeMember` endpoint and a tri-state (`bool?`) ownership gate that never renders owner/member-only actions before `profileDataProvider` resolves.
- Recursive Hive deserialization, a version-guarded background-refresh race fix, band-rename list propagation, and fallback error handling across all 6 band mutations — closing all 4 verification gaps from 02-VERIFICATION.md
- 1. [Rule 3 - Blocking] `_FakeCacheService implements CacheService` in `auth_provider_test.dart` failed to compile
- [Rule scope-boundary] `TrackListData`/`TrackDetailData`'s background-refresh cache write isn't version-guarded
- 1. [Rule 1 - Bug] `SelectedBandIdFilter` needed a public `setFilter()` method instead of the plan's literal `notifier.state = value` call site
- Closed all 5 track-management gaps found by code review/verification: an EditTrackScreen crash on unrecognized keys, a data-loss bug where cleared optional fields silently stayed stale, a global Tracks tab that never synced with per-band mutations, a no-op "View bands" button, and unvalidated numeric input.
- Per-band setlist list/create/detail stood up end-to-end (Hive cache, Riverpod family providers, three screens) mirroring Phase 3's Track pattern, with a words-based `'42m 35s'` duration format distinct from Track's `mm:ss`
- Per-band setlist info CRUD closed out with an EditSetlistScreen (name/location/date, D-17 always-send-all-fields) and a Cancel/Delete confirm dialog (D-18/D-19), both ungated, mirroring Phase 3's Track edit/delete pattern exactly
- Bulk add-tracks picker (`AddSetlistTracksDialog`), per-row track removal, and a toggleable Edit mode on `SetlistDetailScreen` — both mutations always re-fetch via the existing provider `refresh()` rather than computing duration/track-count client-side.
- Drag-and-drop setlist track reordering via Flutter SDK's ReorderableListView, submitting `PUT .../tracks/reorder` immediately on drop with a local-only state patch on success — zero new pub.dev dependencies.
- Global cross-band Setlists tab (`SetlistsScreen`) with band-filter dropdown, backed by a new `GET /api/setlist/list` client method and cache-first `UserSetlistsListData` provider, plus the D-21 bottom-nav reorder to Home/Bands/Tracks/Setlists/Profile.
- Connectivity detection (connectivity_plus, seeded + fail-safe-offline), a global OfflineBanner, a reusable SyncStatusBadge (10m-hidden/30m-warning), and a `{data, syncedAt}` timestamp envelope applied to all 10 `cache_service.dart` cache keys — proven end-to-end on Profile and Home.
- BandsListSyncedAt/BandDetailSyncedAt companion notifiers plus source-blocked (`onPressed: null`, not just disabled-looking) connectivity gating applied across all 9 Bands mutation entry points — FAB, AppBar icon, ListTiles, and 6 in-form/in-dialog submit buttons with D-14 live reactivity — establishing the exact shape Tracks/Setlists (Plans 03/04) replicate with no new design decisions.
- Tracks entity gains the same Wave-1 staleness-badge and Wave-2 connectivity-gated-mutation shape proven on Bands (05-02) and Profile/Home (05-01): per-cache-key `syncedAt` on `tracks_provider.dart`, `SyncStatusBadge` on all 3 Tracks screens, and `isOnlineProvider`-gated Add-track FAB / Edit / Delete with live in-form reactivity.
- Setlists gains the same staleness-badge and connectivity-gated-mutation treatment as Bands/Tracks, extended to a UI-mode toggle: setlist detail's Edit/Done switch is itself blocked at the source offline (D-12), and live-collapses the reorder/remove surface back to a read-only list if connectivity drops mid-session (D-14).
- A deterministic static-content regression guard proving all 10 cached screens render `SyncStatusBadge` and all 19 mutation-control files reference `isOnlineProvider`, plus one real running-app test proving the offline banner is a single consistent app-wide signal across all 5 bottom-nav tabs.

---
