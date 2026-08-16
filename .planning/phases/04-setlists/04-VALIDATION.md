---
phase: 04
slug: setlists
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-16
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | none — flutter test auto-discovers `test/` and `*_test.dart` files |
| **Quick run command** | `flutter test test/providers/setlists_provider_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/providers/setlists_provider_test.dart -k "SetlistListData or SetlistDetailData"` (or the relevant feature test for the task being built)
- **After every plan wave:** Run `flutter test` (full suite)
- **Before `/gsd-verify-work`:** Full suite must be green, plus manual UAT of drag-and-drop reordering (no automated e2e test for gesture interactions)
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-XX | 01 | 1 | SETL-01 | — | N/A | unit | `flutter test test/providers/setlists_provider_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-02 | — | N/A | unit | `flutter test test/features/setlists/create_setlist_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-03 | — | N/A | unit | `flutter test test/providers/setlists_provider_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-04 | — | N/A | unit | `flutter test test/features/setlists/edit_setlist_screen_test.dart` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-05 | — | N/A | unit | `flutter test test/providers/setlists_provider_test.dart::removeFromList` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-06 | — | N/A | unit | `flutter test test/providers/setlists_provider_test.dart::addTracks` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-07 | — | N/A | unit | `flutter test test/providers/setlists_provider_test.dart::removeTrack` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-08 | — | N/A | integration | `flutter test test/features/setlists/setlist_detail_screen_test.dart::drag_reorder` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-09 | — | N/A | unit | `flutter test test/features/setlists/setlist_detail_screen_test.dart::duration_display` | ❌ W0 | ⬜ pending |
| 04-01-XX | 01 | 1 | SETL-10 | — | N/A | unit | `flutter test test/providers/setlists_provider_test.dart::UserSetlistsListData` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Task IDs are placeholders — the planner assigns real task IDs; this table is refined once PLAN.md exists.*

---

## Wave 0 Requirements

- [ ] `test/providers/setlists_provider_test.dart` — SetlistListData (cache-first), SetlistDetailData (detail + patching), UserSetlistsListData (filter-aware), SelectedBandIdFilter (filter setter). Mirror Phase 3's `test/providers/tracks_provider_test.dart` structure. Cover cache hit/miss, background refresh, WR-02 race-condition guards, deduplication, filter changes.
- [ ] `test/features/setlists/create_setlist_screen_test.dart` — form submission with/without optional fields, picker selection, correct trackIds array, error display on API failure.
- [ ] `test/features/setlists/edit_setlist_screen_test.dart` — all-fields-always-sent pattern (null for cleared fields), navigation on success, error display on failure.
- [ ] `test/features/setlists/setlist_detail_screen_test.dart` — read-only vs. Edit mode toggle, drag-and-drop reorder widget, immediate reorder API call on drop, duration display, track add/remove.
- [ ] `test/features/setlists/setlists_screen_test.dart` — global Setlists tab flat list with band-name badge, filter dropdown, UserSetlistsListData rebuild on filter change.
- [ ] `test/cache/cache_service_test.dart` — add setlists box tests: writeBandSetlists, readBandSetlists, writeSetlistDetail, readSetlistDetail, writeUserSetlists, readUserSetlists. Follow Phase 1's cache_service_test pattern.
- [ ] Drag-and-drop package: add chosen package (e.g. `flutter pub add reorderable_grid_view`) — not yet added.

*(Existing flutter_test + riverpod container test infrastructure covers all phase requirements; no new framework setup needed.)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Drag-and-drop reorder gesture | SETL-08 | No automated e2e coverage for gesture interactions in this codebase | Open a setlist with 3+ tracks, drag a track to a new position, confirm order updates on screen and PUT request fires immediately |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
