# Phase 15: Carried-Over Fixes & Setlist Date Picker - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-27
**Phase:** 15-Carried-Over Fixes & Setlist Date Picker
**Areas discussed:** Date field interaction, Date picker range & defaults, Invite-code copy fix scope, Verification re-stamp evidence

---

## Date Field Interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Read-only, tap opens picker | TextFormField becomes readOnly, wrapped so any tap opens showDatePicker. No typing. | ✓ |
| Editable + calendar icon | Keep typable, add calendar IconButton suffixIcon. | |
| You decide | Claude picks simplest option matching SETL-13 wording. | |

**User's choice:** Read-only, tap opens picker

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — add clear (X) button | suffixIcon clears the date once set, eventDate becomes null on submit. | ✓ |
| No — picker only sets, never clears | Once a date is picked it can only be replaced, not cleared. | |

**User's choice:** Yes — add a clear (X) button
**Notes:** None.

---

## Date Picker Range & Defaults

| Option | Description | Selected |
|--------|-------------|----------|
| Wide open: 10y back, 5y forward | firstDate now-10y, lastDate now+5y. | |
| Past + near future only | firstDate now-5y, lastDate now+2y. | ✓ |
| You decide | Claude picks a reasonable wide-open bound. | |

**User's choice:** Past + near future only (firstDate = now-5y, lastDate = now+2y)

| Option | Description | Selected |
|--------|-------------|----------|
| Existing date if set, else today | Edit screen opens to current eventDate; create screen opens to today. | ✓ |
| Always today | Picker always opens to today regardless of existing eventDate. | |

**User's choice:** Existing date if set, else today
**Notes:** None.

---

## Invite-Code Copy Fix Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Only the copy-icon button loses isOnline gate | Copy button always enabled; rotate/regenerate button and everything else stays gated. | ✓ |
| You decide after reading the code | Claude confirms exact icon scope during planning/research. | |

**User's choice:** Only the copy-icon button loses isOnline gate
**Notes:** Confirmed via grep that band_detail_screen.dart has two icon buttons in the ~256-273 range (copy + rotate/regenerate) sharing the isOnline gate today.

---

## Verification Re-Stamp Evidence

| Option | Description | Selected |
|--------|-------------|----------|
| Update 02-VERIFICATION.md in place | Edit the milestones/v1.0-phases/02-bands/02-VERIFICATION.md frontmatter + gap entries directly with current evidence. | ✓ |
| New re-verification report for phase 15 | Leave 02-VERIFICATION.md untouched; write a new 15-VERIFICATION-REAUDIT.md. | |
| You decide | Claude picks based on existing repo convention. | |

**User's choice:** Update 02-VERIFICATION.md in place
**Notes:** Grep during discussion confirmed all 4 gaps (Hive deep-convert, mutation error handling, band-rename list propagation, background-refresh version guard) already have fixes present in current code — re-stamping is evidence documentation, not new implementation. Executor must still independently re-verify each artifact (including 3 mutation sites not directly checked during discussion) before writing the re-stamp.

---

## Claude's Discretion

None — all 4 areas were fully discussed with concrete choices.

## Deferred Ideas

None — discussion stayed within phase scope.
