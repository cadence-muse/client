# Deferred Items — Plan 07-02

Logged during 07-02 execution (Home/Profile online-first). These are
pre-existing failures unrelated to 07-02's files
(`lib/providers/homepage_provider.dart`, `lib/features/home/home_screen.dart`,
`lib/providers/profile_provider.dart`, `lib/features/profile/profile_screen.dart`
and their tests) — confirmed via `git diff 94e671975d2 HEAD --stat`, which
shows only those 4 lib files + 4 test files touched by this plan. Full-suite
`flutter test` (334 total tests) surfaces 4 pre-existing failures, all
out of scope per the Scope Boundary rule:

1. **`test/regression/offline_trust_regression_test.dart` — "every cached
   screen renders SyncStatusBadge (OFFL-04 regression guard)"** — expected to
   fail during waves 1-2 of this phase; 07-05 (wave 3, depends on 07-01
   through 07-04) explicitly rewrites this test's assertion once every
   screen's badge removal has landed. Not a bug — this is by design per
   07-05-PLAN.md.

2. **`test/features/bands/band_detail_screen_test.dart` — "Delete and Leave
   tiles are disabled while offline (owner sees Delete, member sees Leave)"**
   and **"Remove icon on a member row is disabled while offline, enabled
   while online"** — pre-existing failures in 07-01's Bands scope (band
   detail screen), unrelated to Home/Profile. Present at this worktree's base
   commit (`94e671975d29a69f9585aa3cb7543bcb8d0a47c1`), before any 07-02
   change.

3. **`test/widget_test.dart` — "bottom navigation switches between tabs"**
   — fails because it exercises the full `CadenceApp` without overriding
   `isOnlineProvider`; under online-first (introduced by 07-01),
   `BandsListData.build()` now reads `isOnlineProvider`, which defaults to
   `false` (fail-safe) with no platform-channel mock in the test sandbox,
   so the Bands tab renders `OfflineNoCacheView` instead of the seeded
   `'B.A.T.H.'` band. Pre-existing gap from 07-01's online-first rollout,
   unrelated to Home/Profile.

Plan 07-02's own `<verification>` block (the 4 homepage/profile test files +
full-tree `flutter analyze`) passes cleanly — see 07-02-SUMMARY.md.

## Update — 07-05 (wave 3)

Item 1 above is now resolved: `offline_trust_regression_test.dart` was
rewritten in 07-05 Task 2 to assert the OFFL-07/OFFL-08 aggregate claim
(badge absence + `OfflineNoCacheException` presence across the 10 cached
screens) instead of the retired OFFL-04 badge-presence claim. All 4 tests in
that file pass.

Items 2 and 3 remain pre-existing, unrelated to 07-05's files
(`lib/widgets/sync_status_badge.dart` deletion,
`test/widgets/sync_status_badge_test.dart` deletion, and
`test/regression/offline_trust_regression_test.dart` rewrite). They belong to
07-01's Bands scope (band detail offline-disabled-tiles wiring and the
full-`CadenceApp` widget_test's missing `isOnlineProvider` override) and are
explicitly out of scope for this plan per the Scope Boundary rule. Full-suite
`flutter test` after 07-05: 368 total, 3 failing (items 2 and 3 above; item 1
now green), 0 new failures introduced by this plan.
