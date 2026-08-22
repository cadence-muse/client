---
phase: 10
slug: searchable-setlist-track-picker
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-22
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in Flutter testing) |
| **Config file** | analysis_options.yaml (existing) |
| **Quick run command** | `flutter test test/features/setlists/ -k "search" --tags="phase-10" -x` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/setlists/ -k "search" --tags="phase-10" -x`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 0 | SETL-12 | — | N/A | unit | `flutter test test/providers/search_debounce_test.dart -x` | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 0 | SETL-12 | — | N/A | unit | `flutter test test/api/public_api_test.dart::listBandTracksWithSearchQuery -x` | ❌ W0 | ⬜ pending |
| 10-01-03 | 01 | 0 | SETL-12 | — | N/A | unit | `flutter test test/features/setlists/search_filter_test.dart::offlineSubstringMatch -x` | ❌ W0 | ⬜ pending |
| 10-02-01 | 02 | 1 | SETL-12 | — | N/A | integration | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart::searchFieldRendered -x` | ❌ W0 | ⬜ pending |
| 10-02-02 | 02 | 1 | SETL-12 | — | N/A | integration | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart::clearSearchFilter -x` | ❌ W0 | ⬜ pending |
| 10-02-03 | 02 | 1 | SETL-12 | — | N/A | integration | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart::offlineEmptySearchMessage -x` | ❌ W0 | ⬜ pending |
| 10-02-04 | 02 | 1 | SETL-12 | — | N/A | integration | `flutter test test/features/setlists/add_setlist_tracks_dialog_test.dart::addTracksWithSearchActive -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*(Task IDs above are provisional — planner assigns final plan/task numbering; this table maps each RESEARCH.md test case to an expected wave placement: Wave 0 = pure logic (debounce, query encoding, offline filter), Wave 1 = widget/integration tests depending on the dialog UI built in the same wave.)*

---

## Wave 0 Requirements

- [ ] `test/features/setlists/add_setlist_tracks_dialog_test.dart` — widget tests for search field rendering, debounce behavior, selection with search active, "No tracks match" message
- [ ] `test/api/public_api_test.dart` — unit test for `listBandTracks(bandId, searchQuery: '...')` query parameter encoding
- [ ] `test/providers/search_debounce_test.dart` — unit test for 300ms timer debounce logic (if extracted to a helper)
- [ ] `test/features/setlists/search_filter_test.dart` — unit test for offline substring matching (title + artist, case-insensitive)

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
