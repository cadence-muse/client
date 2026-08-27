# Phase 15: Carried-Over Fixes & Setlist Date Picker - Context

**Gathered:** 2026-08-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Three unrelated fixes bundled into one phase per ROADMAP.md:
1. **BAND-13** — invite-code copy button on band detail screen works while offline (currently incorrectly gated behind `isOnline`).
2. **QA-01** — four previously-flagged gaps in `02-VERIFICATION.md` (Hive deep-convert, mutation error handling, band-rename list propagation, background-refresh version guard) are re-checked against current code and re-stamped resolved.
3. **SETL-13** — setlist create/edit date field uses the platform's native `showDatePicker` instead of raw text entry.

No new capabilities. No offline mutation support beyond what's stated above.

</domain>

<decisions>
## Implementation Decisions

### Setlist Date Field Interaction (SETL-13)
- **D-01:** Date `TextFormField` (in both `create_setlist_screen.dart` and `edit_setlist_screen.dart`) becomes `readOnly: true`, tap opens `showDatePicker` via `GestureDetector`/`InkWell` (or `onTap` if the widget supports it directly). No manual typing of the date string anywhere.
- **D-02:** A clear (X) `suffixIcon` appears once a date is set; tapping it resets `_dateController` back to `''` so `eventDate` submits as `null`. Preserves the existing optional-date behavior — a setlist can still have no date.

### Date Picker Range & Defaults (SETL-13)
- **D-03:** `firstDate` = now − 5 years, `lastDate` = now + 2 years. Tighter bound; setlists are for recent/near-term shows, not decade-spanning archives.
- **D-04:** `initialDate` = the setlist's existing `eventDate` (parsed via `DateTime.parse`) when editing an already-dated setlist; falls back to today when creating a new setlist or editing one with no date yet.

### Invite-Code Copy Fix Scope (BAND-13)
- **D-05:** Only the copy-icon `IconButton` (currently `band_detail_screen.dart` ~line 256-262, calls `_copyInviteCode`) loses its `isOnline` gate — always enabled, no `Tooltip` block message when offline. Every other action on the screen (rotate/regenerate invite code at ~line 268-273, edit, delete, leave, remove-member) stays gated behind `isOnline` exactly as today — those are real network mutations, only clipboard copy is local.

### Verification Re-Stamp (QA-01)
- **D-06:** Update `.planning/milestones/v1.0-phases/02-bands/02-VERIFICATION.md` in place — flip each of the 4 gaps' status to resolved, cite current file:line evidence, update frontmatter `status`/`score`. Matches the file's existing `audit_acknowledged` precedent from the v1.2 re-check.
- **D-07:** Confirmed during discussion (grep against current code) that all 4 gaps are already fixed:
  - Hive deep-convert: `_deepConvert()` present at `lib/cache/cache_service.dart:37`.
  - Mutation error handling: generic `catch (_)` fallback present alongside `on ApiException catch (e)` in `edit_band_screen.dart:75,77` and `create_band_screen.dart:53,55` (verify remaining 4 mutation sites listed in the original gap during planning/execution).
  - Band-rename list propagation: `edit_band_screen.dart` patches `bandsListDataProvider` via `ref.exists(...)` guard at line 68-70.
  - Background-refresh version guard: `_version` counter with `capturedVersion` guard present in `lib/providers/bands_provider.dart` (both `BandsListData` and `BandDetailData`, lines ~36-145 and ~172-247).
  - This is re-stamping existing evidence, not new implementation work — but the executor must independently re-verify each artifact (including the 2 unconfirmed mutation sites: `confirm_delete_band_dialog.dart`, `confirm_leave_band_dialog.dart`, `confirm_remove_member_dialog.dart`) before writing the re-stamp, not just trust this note.

### Claude's Discretion
None — all 4 areas were fully discussed with concrete choices.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API Contract
- `lib/api/publicapi.yml` (search `eventDate`, ~lines 1028, 1061, 1085, 1117, 1158) — `eventDate` is `type: string, format: date` (date-only, e.g. `YYYY-MM-DD`, no time component).

### Verification Target
- `.planning/milestones/v1.0-phases/02-bands/02-VERIFICATION.md` — the file to update in place for QA-01. Contains the 4 original gap descriptions with artifact paths and line numbers as they were at time of original audit (lines have since shifted — re-locate before citing).

### Requirements
- `.planning/REQUIREMENTS.md` — BAND-13, QA-01, SETL-13 definitions.
- `.planning/ROADMAP.md` §"Phase 15" — success criteria and phase boundary.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None specific to `showDatePicker` — this is the first use of it in the codebase (grep for `showDatePicker`/`DatePicker` across `lib/` returned no matches). No existing pattern to follow; standard Flutter Material `showDatePicker` API applies directly.
- `l10n.commonDateLabel` / `l10n.createSetlistDateHint` (`lib/l10n/app_en.arb:99,242`, `app_ru.arb:99,242`) — existing localized label/hint; hint text ("YYYY-MM-DD") becomes unnecessary once the field is picker-only and may need removal or repurposing.

### Established Patterns
- `isOnline` gating pattern: `ref.watch(isOnlineProvider)` + `Tooltip(message: isOnline ? '' : l10n.commonRequiresConnection)` wrapping a disabled `onPressed: null` — used consistently across all band mutation actions (`band_detail_screen.dart`, `edit_band_screen.dart`, `create_band_screen.dart`, `confirm_leave_band_dialog.dart`, `confirm_remove_member_dialog.dart`, `confirm_delete_band_dialog.dart`). BAND-13 removes this wrapper from the copy button only.
- `_version` counter + `capturedVersion` guard pattern in `lib/providers/bands_provider.dart` — the reference implementation QA-01's background-refresh gap check confirms against.
- `formatEventDate()` in `lib/features/setlists/setlist_formatting.dart:26` — parses `eventDate` ISO string for display (`'MMM d, yyyy'`, falls back to `'No date set'`). Unaffected by the picker change but confirms `eventDate` round-trips as a plain ISO date string.

### Integration Points
- `create_setlist_screen.dart:131-137` and `edit_setlist_screen.dart:151-159` — the two `TextFormField` sites to convert to read-only + tap-opens-picker.
- `band_detail_screen.dart:256-273` — the two-icon-button block (copy at ~256-262, rotate/regenerate at ~268-273); only the first loses its `isOnline` gate.

</code_context>

<specifics>
## Specific Ideas

No specific UI mockups or external references given — standard Flutter Material `showDatePicker` with the range/default rules in D-03/D-04 above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-Carried-Over Fixes & Setlist Date Picker*
*Context gathered: 2026-08-27*
