---
phase: 03
slug: tracks
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-16
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (bundled with Flutter SDK) + riverpod testing utilities |
| **Config file** | None (flutter_test integrated into Flutter SDK) |
| **Quick run command** | `flutter test test/features/tracks/ -k "quick_validation"` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/features/tracks/` (and `test/providers/tracks_provider_test.dart` for provider tasks)
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | TRACK-01 | — | GET track list is cache-first, displays tracks for a band | unit | `flutter test test/providers/tracks_provider_test.dart -k "cache_first_band_list"` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | TRACK-01 | — | Track list screen renders cached/fetched tracks | widget | `flutter test test/features/tracks/track_list_screen_test.dart -k "displays_tracks_list"` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 0 | TRACK-02 | — | Create track form validates required title/artist | widget | `flutter test test/features/tracks/create_track_screen_test.dart -k "shows_validation_errors"` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 0 | TRACK-02 | — | POST /api/band/{bandId}/track succeeds with valid data | widget | `flutter test test/features/tracks/create_track_screen_test.dart -k "submits_with_valid_data"` | ❌ W0 | ⬜ pending |
| 03-01-05 | 01 | 0 | TRACK-03 | — | Track detail screen displays full schema | widget | `flutter test test/features/tracks/track_detail_screen_test.dart -k "displays_full_detail"` | ❌ W0 | ⬜ pending |
| 03-01-06 | 01 | 0 | TRACK-04 | — | PUT /api/band/{bandId}/track/{trackId} updates detail + invalidates cache | widget | `flutter test test/features/tracks/edit_track_screen_test.dart -k "submits_edits"` | ❌ W0 | ⬜ pending |
| 03-01-07 | 01 | 0 | TRACK-05 | — | Delete confirmation dialog calls DELETE and navigates back to list | widget | `flutter test test/features/tracks/track_detail_screen_test.dart -k "delete_dialog_deletes"` | ❌ W0 | ⬜ pending |
| 03-01-08 | 01 | 0 | TRACK-06 | — | GET /api/track/list displays cross-band track list | widget | `flutter test test/features/tracks/tracks_screen_test.dart -k "displays_global_list"` | ❌ W0 | ⬜ pending |
| 03-01-09 | 01 | 0 | TRACK-06 | — | Global track list filters by band | widget | `flutter test test/features/tracks/tracks_screen_test.dart -k "filters_by_band"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/features/tracks/track_list_screen_test.dart` — covers TRACK-01 (list display, cache-first behavior)
- [ ] `test/features/tracks/track_detail_screen_test.dart` — covers TRACK-03 (detail view) and TRACK-05 (delete dialog)
- [ ] `test/features/tracks/create_track_screen_test.dart` — covers TRACK-02 (form validation, submission, error handling)
- [ ] `test/features/tracks/edit_track_screen_test.dart` — covers TRACK-04 (edit form behavior)
- [ ] `test/features/tracks/tracks_screen_test.dart` — covers TRACK-06 (global list, filter dropdown)
- [ ] `test/providers/tracks_provider_test.dart` — provider unit tests: cache-first loading, background refresh, version guards, cache invalidation
- [ ] `test/features/tracks/confirm_delete_track_dialog_test.dart` — delete dialog UX (cancel button, delete button, error handling)
- [ ] Mock HTTP responses for track endpoints in test helpers (extend existing `MockClient` from test/widget_test.dart)

*(Existing test infrastructure from Phase 1/2 — mock HTTP client, Riverpod test overrides, in-memory CacheService — is already in place; new tests plug into it.)*

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
