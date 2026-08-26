# Milestones

## v1.2 i18n and Duration Input (Shipped: 2026-08-26)

**Phases completed:** 4 phases, 20 plans, 41 tasks

**Key accomplishments:**

- DurationTextInputFormatter auto-shapes digit keystrokes into mm:ss (capped at 99:59) while parseDurationSeconds() independently re-validates at submit time, wired end-to-end into both Create and Edit Track forms.
- Retired setlist_formatting.dart's words-based `asMinutesAndSeconds` extension; every setlist screen (list rows, detail rows, setlist totals) now renders duration via the pre-existing `track_formatting.dart` `asMinutesSeconds` mm:ss extension.
- ARB/gen-l10n pipeline with a SharedPreferences-backed LocaleController (mirroring ThemeController) wired end-to-end on the Settings screen — live language switch, English default, background-tab propagation, and restart/logout persistence, all proven by automated unit/widget/integration tests.
- Landed the complete ~130-key ARB vocabulary for all of phase 13 in one batch, proved the ARB/gen-l10n/AppLocalizations/tester.strings pipeline handles ICU plurals and placeholders (not just simple strings) end-to-end on the Bands tab and Band Detail screen, with correct Russian one/few/many/other plural resolution verified at the CLDR boundaries.
- Home tab and shared band-picker bottom sheet fully localized (EN/RU) via AppLocalizations, with locale_live_switch_test.dart now proving cross-tab locale propagation against real rendered Home AppBar text instead of just the ambient `Localizations.localeOf()` value.
- Localized the bottom-nav bar's 5 labels and the offline banner's message via AppLocalizations, migrated both cross-cutting tests off hardcoded English literals, and fixed a regression this introduced in an unrelated locale-switch test that tapped the same nav labels.
- Localized the shared offline-empty-state widget (consumed by ~6 list screens) and the login/signup screen, including its two thrown-exception error messages, using ARB keys landed by 13-01.
- Localized edit_setlist_screen.dart, confirm_delete_setlist_dialog.dart, and setlist_list_screen.dart to AppLocalizations, completing the Setlists domain sweep alongside 13-09.
- Localized the per-band Tracks feature's list, detail, and delete-confirm screens to route every visible string through `AppLocalizations`, using ARB keys already landed by 13-01.
- create_track_screen.dart, edit_track_screen.dart, and the global cross-band tracks_screen.dart (last of the 5 bottom-nav tabs) fully localized via AppLocalizations, with all three widget test files migrated to tester.strings assertions.
- Shared `ApiExceptionLocalization.localizedMessage()` extension mapping the 5-value `ErrorCode` enum to localized ARB messages, proven end-to-end on `CreateBandScreen` with a passing RED/GREEN widget test.
- Mechanical one-line swap of `e.message` -> `e.localizedMessage(l10n)` across all 7 remaining Bands-feature `on ApiException catch (e)` sites, proven with 2 new known-error-code regression tests.
- Wired create/edit/delete-track error catch sites to the shared `localizedMessage` extension, then refactored login's `already_exists` and change-password's `invalid_input` overrides onto the same `overrides` parameter mechanism (D-04), retiring the last 2 bespoke error-handling implementations in the app and adding LoginScreen's first-ever test coverage.
- Wired the last 5 setlist-feature `on ApiException catch (e)` sites (create/edit/delete-setlist, remove-track SnackBar, add-tracks) to `ApiExceptionLocalization.localizedMessage()`, completing Phase 14's full-app catch-site coverage.

---

## v1.1 UI Improvements (Shipped: 2026-08-22)

**Phases completed:** 6 phases, 13 plans, 28 tasks

**Key accomplishments:**

- Password change end-to-end on the Profile screen (USER-03), plus three client-first `publicapi.yml` field additions (`TrackListItem.key`, `SetlistListItem.eventLocation`, `BandListItem.ownerId`) that unblock Wave 2's display plans.
- Bands list rows and the Band detail screen both surface "N members • Owner/Member" by exposing `BandDetailScreen`'s tri-state ownership helper as a public static method reused across both screens (BAND-10).
- Track list rows and the Track detail screen both show icon-based key/duration/notes indicators (Icons.music_note/Icons.timer/Icons.notes), replacing prefixed "Duration:"/"Key:"/"Notes:" text, with tap-to-expand for long notes.
- Setlist list and detail screens now show `Icons.location_on`/`Icons.timer` icon-based indicators for event location and duration, replacing the old "N tracks, Xm Ys" trailing text and "Duration: ..." prefixed label.
- Migrated removeSetlistTrack to the batch DELETE .../tracks endpoint and listUserTracks/listUserSetlists from GET to POST, matching the fe72e78 publicapi.yml schema update with zero regressions across the 315-test suite.
- Bands tab and band detail screen flipped from cache-first to online-first via a rewritten `BandsListData`/`BandDetailData` `build()` contract, plus two new shared artifacts (`OfflineNoCacheException`, `OfflineNoCacheView`) every remaining Phase 7 plan reuses verbatim
- Home and Profile tabs flipped from cache-first to online-first by applying 07-01's exact template minus the `_version` guard — neither provider has local-mutation methods to race
- All three track providers (TrackListData, TrackDetailData, UserTracksListData) and their three screens flipped from cache-first to online-first using 07-01's proven pattern, with the cross-band Tracks tab getting D-01 tab-switch-refetch wiring and the two pushed-route screens getting none per D-02
- All three setlist providers (SetlistListData, SetlistDetailData, UserSetlistsListData) and their three screens (SetlistsScreen tab, SetlistListScreen, SetlistDetailScreen) flipped from cache-first to online-first, mirroring 07-01's Bands tracer pattern one entity level down
- Deleted the now-fully-unused `SyncStatusBadge` widget and its test, and rewrote the cross-cutting `offline_trust_regression_test.dart` guard so it asserts the phase's real final state (badge gone, `OfflineNoCacheException` wired everywhere) instead of the retired Phase-5 badge-presence claim — closing out Phase 7's OFFL-07/OFFL-08 requirements.
- Owner-gated invite-code rotation (BAND-11) and ownership transfer (BAND-12) added to `band_detail_screen.dart` via two new confirm dialogs, two new `PublicApi` methods, and two new provider local-patch methods, with the member-row `person_remove` icon migrated into a `PopupMenuButton` alongside a new "Make owner" action.
- Home screen restructured into a unified welcome-card + Quick Actions layout with three buttons (Add Band/Song/Setlist); Add Song and Add Setlist open a shared `band_picker_sheet.dart` bottom sheet backed by `bandsListDataProvider` before handing off to the existing create screens.
- Search TextField added to AddSetlistTracksDialog: offline substring filtering on title/artist, plus a forward-compatible debounced `searchQuery` wire parameter on `ListBandTracks` that the backend currently ignores online.

---

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
