---
phase: 15-carried-over-fixes-setlist-date-picker
verified: 2026-08-27T00:00:00Z
status: gaps_found
score: 2/3 success criteria verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "User creating or editing a setlist taps the date field and gets the platform's native showDatePicker instead of typing a raw date string (SETL-13 success criterion 3)"
    status: failed
    reason: "edit_setlist_screen.dart's _showDatePickerDialog parses the persisted eventDate but does not clamp the parsed date into the picker's [firstDate, lastDate] window. For any setlist with an eventDate older than 5 years or more than 2 years in the future (e.g., a gig from 6 years ago), initialDate will fall outside the allowed range, and Flutter's showDatePicker will throw an AssertionError in debug/test builds. The existing test only covers an unparseable date (falls back to now), never a parseable-but-out-of-range date, leaving this crash path untested and unguarded."
    artifacts:
      - path: "lib/features/setlists/edit_setlist_screen.dart"
        issue: "Lines 117-142: _showDatePickerDialog parses _dateController.text at line 124 but passes the result unclamped to showDatePicker at line 131. No clamping into [firstDate, lastDate] after the parse."
      - path: "test/features/setlists/edit_setlist_screen_test.dart"
        issue: "Line 331-360: Test 'a malformed persisted eventDate falls back to today...' only exercises unparseable dates (eventDate: 'not-a-date'). No test for a parseable-but-out-of-range date (e.g., eventDate: '2020-01-01' — 6 years ago)."
    missing:
      - "Clamp the parsed initialDate into [firstDate, lastDate] after parsing: `if (initialDate.isBefore(firstDate)) { initialDate = firstDate; } else if (initialDate.isAfter(lastDate)) { initialDate = lastDate; }`"
      - "Add a test exercising an out-of-range parseable date (e.g., '2020-01-01') to catch this crash before shipping"
deferred: []
behavior_unverified_items: []
coincidental_reliance_items: []
human_verification: []
---

# Phase 15: Carried-Over Fixes (Setlist Date Picker + Offline Copy) Verification Report

**Phase Goal:** Users get the invite-code copy button working offline, previously-flagged verification gaps confirmed still resolved in code, and setlist dates entered via the platform's native date picker.

**Verified:** 2026-08-27
**Status:** gaps_found
**Re-verification:** No — initial verification

## Summary

Phase 15 delivers three success criteria:

1. **SC1 — Invite-code copy works offline:** VERIFIED ✓ — Copy button has no `isOnline` gate, works end-to-end with clipboard write and snackbar display. Widget test confirms offline tap succeeds.

2. **SC2 — 02-VERIFICATION.md gaps re-verified:** VERIFIED ✓ — All 4 previously-flagged gaps (Hive deep-convert, mutation error handling, band-rename list propagation, background-refresh version guard) have been independently re-read in current code and re-stamped resolved with fresh file:line evidence. The file's frontmatter status is now `resolved` with a new `audit_acknowledged` (v1.3) entry.

3. **SC3 — Setlist dates use native date picker:** PARTIALLY COMPLETED, CRITICAL BLOCKER — Both `CreateSetlistScreen` and `EditSetlistScreen` successfully replace the raw-text date field with Flutter's native `showDatePicker`. However, `EditSetlistScreen` has a critical runtime crash in the unexercised code path: when editing a setlist with an `eventDate` older than 5 years or more than 2 years in the future, the date parser succeeds but the initialDate is passed unclamped to `showDatePicker`, which asserts that initialDate ∈ [firstDate, lastDate]. Any attempt to edit such a setlist will throw an AssertionError. The existing test suite misses this because it only tests malformed (unparseable) dates, not out-of-range (parseable but outside the window) dates.

**Plan Completion:** 100% (both 15-01 and 15-02 tasks committed, tests passing per SUMMARY reports)

**Goal Achievement:** 67% (2/3 success criteria verified; 1/3 blocked by a runtime crash in production-viable data)

## Success Criteria Verification

### SC1: Invite-Code Copy Button Works Offline (BAND-13)

| Criterion | Evidence | Status |
|-----------|----------|--------|
| Button has no `isOnline` gate | `band_detail_screen.dart:255-261` — copy `IconButton.onPressed` is unconditional `() => _copyInviteCode(context, inviteCode)` with no ternary or null-coalescing | ✓ VERIFIED |
| Tooltip is unconditional | `band_detail_screen.dart:256` — tooltip message is `l10n.bandDetailCopyTooltip` with no `isOnline ? ... : ...` | ✓ VERIFIED |
| Other band actions remain gated | `band_detail_screen.dart:62-79` (edit), `264-279` (rotate), `305-327` (delete, owner), `329-358` (leave, member) all retain `isOnline` gates | ✓ VERIFIED |
| Offline copy test passes | `test/features/bands/band_detail_screen_test.dart` — new test "tapping Copy while offline still copies the trimmed invite code and shows the Copied! snackbar" verifies end-to-end with `isOnline: false` | ✓ VERIFIED (per 15-02-SUMMARY.md) |

**Score:** 4/4 criteria met — offline copy fully working.

---

### SC2: 02-VERIFICATION.md Gaps Re-Verified (QA-01)

The file `.planning/milestones/v1.0-phases/02-bands/02-VERIFICATION.md` has been updated:

| Gap | Original Status | Current Status | Evidence | Verified |
|-----|-----------------|----------------|----------|----------|
| Hive deep-convert | gaps_found | resolved | `lib/cache/cache_service.dart:23-47` — `_HiveStore.get()` calls recursive `_deepConvert()` helper normalizing nested Map/List before return; fallback on null/empty confirmed | ✓ VERIFIED |
| Mutation error handling | gaps_found | resolved | All 6 mutation sites (create, join, edit, delete, leave, remove-member) have `on ApiException catch (e)` followed by generic `catch (_)` fallback showing `commonSomethingWentWrong` | ✓ VERIFIED |
| Band-rename list propagation | gaps_found | resolved | `edit_band_screen.dart:68-72` guards `if (ref.exists(bandsListDataProvider))` before calling `renameBand()`; `BandsListData.renameBand()` (bands_provider.dart:115-125) patches in-place preserving order | ✓ VERIFIED |
| Background-refresh version guard | gaps_found | resolved | `lib/providers/bands_provider.dart` declares `int _version` in both `BandsListData` and `BandDetailData`, captured before network await, discards fetched result on inequality | ✓ VERIFIED |

**Frontmatter updates:**
- `status: gaps_found` → `status: resolved`
- `score` updated to `9/9 requirements verified; 4/4 previously-blocked requirements now resolved`
- All 4 gap entries now carry a `resolution` block with `verified_at: 2026-08-27` and fresh file:line evidence
- New `audit_acknowledged` entry appended: `milestone: v1.3`, `at: 2026-08-27`, `status: resolved`

**Score:** 4/4 gaps re-verified with current evidence — QA-01 fully satisfied.

---

### SC3: Setlist Dates Use Native Date Picker (SETL-13)

| Criterion | Evidence | Status |
|-----------|----------|--------|
| CreateSetlistScreen date field is readOnly with tap-to-open picker | `create_setlist_screen.dart:147-163` — `TextFormField` has `readOnly: true`, `onTap: () => _showDatePickerDialog(context)` | ✓ VERIFIED |
| EditSetlistScreen date field is readOnly with tap-to-open picker | `edit_setlist_screen.dart:178-192` — same `readOnly: true` + `onTap` pattern | ✓ VERIFIED |
| Picker bounds are now ∓ (5, 2) years | `create_setlist_screen.dart:96-98` and `edit_setlist_screen.dart:118-120` — both compute `firstDate = DateTime(now.year - 5, ...)` and `lastDate = DateTime(now.year + 2, ...)` | ✓ VERIFIED |
| CreateSetlistScreen initialDate defaults to now | `create_setlist_screen.dart:99-103` — `initialDate: now` hardcoded | ✓ VERIFIED |
| EditSetlistScreen initialDate pre-populates from existing eventDate | `edit_setlist_screen.dart:122-130` — parses `_dateController.text` with try/catch fallback to `now` | ✓ VERIFIED |
| Picked date round-trips as YYYY-MM-DD | `create_setlist_screen.dart:106-108` and `edit_setlist_screen.dart:137-140` — both write `selected.toIso8601String().split('T')[0]` to controller | ✓ VERIFIED |
| Clear icon (X) suffix empties field and nulls eventDate on submit | `create_setlist_screen.dart:155-161` and `edit_setlist_screen.dart:185-191` — `suffixIcon` conditional on `_dateController.text.isNotEmpty`, taps `setState(() => _dateController.clear())` | ✓ VERIFIED |
| Widget tests pass for both screens | `test/features/setlists/create_setlist_screen_test.dart` and `edit_setlist_screen_test.dart` report 0 failures per 15-01-SUMMARY.md | ✓ VERIFIED (per summary claims) |
| **BLOCKER: EditSetlistScreen date picker crashes for out-of-range dates** | `edit_setlist_screen.dart:117-142` — After parsing `initialDate = DateTime.parse(_dateController.text)` at line 124, the code passes `initialDate` directly to `showDatePicker()` at line 131 WITHOUT clamping it into `[firstDate, lastDate]`. Flutter's `showDatePicker` asserts `initialDate >= firstDate && initialDate <= lastDate`; any setlist with `eventDate` from 6+ years ago or 3+ years in future will crash with AssertionError when the user taps the date field. | ✗ FAILED |
| **TEST GAP: No test for out-of-range parseable date** | `test/features/setlists/edit_setlist_screen_test.dart:331-360` tests malformed date ('not-a-date' → fallback to now), but no test exercises a valid date outside [firstDate, lastDate] (e.g., '2020-01-01'). This crash path is untested. | ✗ FAILED |

**Score:** 6/8 criteria verified; 2 blockers (same root cause — missing initialDate clamping in EditSetlistScreen).

---

## Requirement Traceability

| Requirement | Phase | Mapping | Status |
|-------------|-------|---------|--------|
| BAND-13 | 15 (Plan 02) | Invite-code copy works offline | ✓ VERIFIED |
| QA-01 | 15 (Plan 02) | Gaps in 02-VERIFICATION re-verified | ✓ VERIFIED |
| SETL-13 | 15 (Plan 01) | Setlist date picker uses native showDatePicker | ✗ BLOCKED (crash in EditSetlistScreen) |

**Coverage:** 3/3 requirements mapped; 2/3 verified; 1/3 blocked.

---

## Detailed Gap Analysis

### Gap 1: EditSetlistScreen initialDate Clamping Missing (CR-01 from Code Review)

**What's wrong:** `edit_setlist_screen.dart:124` parses a persisted `eventDate` that may fall outside the picker's `[firstDate, lastDate]` window, then passes the unclamped date to `showDatePicker()` at line 131, which asserts the invariant and crashes.

**When it fails:** Any setlist created/edited with an `eventDate` older than 5 years or more than 2 years in the future. Example:
- Gig from 2020-01-01 (6 years before 2026-08-27): tapping edit date field crashes
- Gig scheduled for 2029-01-01 (3 years after 2026-08-27): tapping edit date field crashes

**Why tests didn't catch it:** `edit_setlist_screen_test.dart:331-360` tests a malformed date ('not-a-date'), which correctly falls back to `now` (inside the range). No test supplies a valid date outside the range.

**Code review evidence:** 15-REVIEW.md, CR-01, lines 36-57, recommends:
```dart
if (_dateController.text.isNotEmpty) {
  try {
    initialDate = DateTime.parse(_dateController.text);
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }
  } catch (_) {
    initialDate = now;
  }
} else {
  initialDate = now;
}
```

**Required fix:**
1. Add clamping logic after parsing in `edit_setlist_screen.dart:_showDatePickerDialog`
2. Add a test exercising an out-of-range parseable date (e.g., setlistOverride with eventDate: '2020-01-01')
3. Verify the test catches any regression

---

## Gaps Summary

| Gap ID | Component | Issue | Severity | Blocker | Closure |
|--------|-----------|-------|----------|---------|---------|
| 1 | `edit_setlist_screen.dart:131` + `test/.../edit_setlist_screen_test.dart` | Missing initialDate clamping + no out-of-range test | CRITICAL | YES | Add clamping + test |

---

## Anti-Patterns Scan

Scanning files modified by phase 15 for debt markers and stubs:

| File | Pattern | Line | Severity | Action |
|------|---------|------|----------|--------|
| `lib/features/setlists/create_setlist_screen.dart` | None found | — | — | ✓ CLEAN |
| `lib/features/setlists/edit_setlist_screen.dart` | None found | — | — | ✓ CLEAN |
| `lib/features/bands/band_detail_screen.dart` | None found | — | — | ✓ CLEAN |
| `test/features/setlists/create_setlist_screen_test.dart` | None found | — | — | ✓ CLEAN |
| `test/features/setlists/edit_setlist_screen_test.dart` | None found | — | — | ✓ CLEAN |
| `test/features/bands/band_detail_screen_test.dart` | None found | — | — | ✓ CLEAN |
| `.planning/milestones/v1.0-phases/02-bands/02-VERIFICATION.md` | None found | — | — | ✓ CLEAN |

---

## Code Review Findings Reconciliation

Code review (15-REVIEW.md) identified 4 findings:

| Finding | ID | Severity | Phase Status |
|---------|----|-----------| ------------|
| EditSetlistScreen crashes on out-of-range initialDate | CR-01 | CRITICAL | ✗ UNRESOLVED (present in code) |
| CreateSetlistScreen picker re-opens on today (UX regression) | WR-01 | WARNING | ✓ ACCEPTABLE (create form has no prior date, trade-off) |
| Missing mounted check after await showDatePicker | WR-02 | WARNING | ✓ ACCEPTABLE (low probability, non-blocking) |
| Duplicated date-window computation | IN-01 | INFO | ✓ ACCEPTABLE (minor refactor opportunity) |

**CRITICAL: CR-01 is not resolved in the submitted code.** Both review recommendation and test evidence confirm the crash path remains present and untested.

---

_Verified: 2026-08-27_
_Verifier: Claude (gsd-verifier)_
