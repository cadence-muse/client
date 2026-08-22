# Phase 6: Foundation Info & Settings Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-20
**Phase:** 6-Foundation Info & Settings Polish
**Areas discussed:** Password API gap, List-screen API gap (Track/Setlist), Band role in list, Icon style

---

## Password change API has no `currentPassword` field

| Option | Description | Selected |
|--------|-------------|----------|
| Extend spec + form asks for it | Add `currentPassword` to `ChangeUserPasswordRequestBody` (client-first, backend follows — SETL-12 precedent); form collects current+new+confirm now | ✓ |
| Match API as-is | Drop "current password" UX; form only asks new password + confirm | |
| Collect but don't send | Ask for current password client-side only, for reassurance, never transmitted | |

**User's choice:** Extend spec + form asks for it.
**Notes:** Matches the SETL-12 precedent already set this milestone (client extends spec ahead of backend).

---

## Track/Setlist list screens missing fields needed for icons

| Option | Description | Selected |
|--------|-------------|----------|
| Extend spec, degrade gracefully | Add `key`/`notes` to `TrackListItem`, `eventLocation` to `SetlistListItem`; icons only render when present | ✓ (modified) |
| Detail screens only | Icons only on detail screens; list screens keep current text-only fields | |

**User's choice:** Extend spec, degrade gracefully — but modified scope: add only `key` to `TrackListItem` (not `notes`), and `eventLocation` to `SetlistListItem`. Both fields optional/not-required.
**Notes:** Notes icon is deliberately detail-only — `TrackListItem` is not being extended with `notes`.

---

## Bands list has no role/owner data

| Option | Description | Selected |
|--------|-------------|----------|
| Extend spec with role field | Add a role/owner field to `BandListItem`; member count already works via `membersCount` | ✓ (modified) |
| Detail screen only | List shows member count only; role badge stays detail-screen-only | |

**User's choice:** Extend spec — but modified: add `ownerId` (not a separate `role` string) to `BandListItem`, so the list screen can reuse `band_detail_screen.dart`'s existing `_isOwner`/`_ownershipStatus` comparison logic instead of trusting a server-computed role string.

---

## Icon style for key/duration/notes/location

| Option | Description | Selected |
|--------|-------------|----------|
| Icon + inline row | Small Material icons with tight labels/values inline, e.g. 🎵 C  ⏱ 3:45  📝 | ✓ |
| Icon only, tooltip for value | Compact icon-only chips; tap/tooltip reveals value | |
| Let Claude decide | No strong preference | |

**User's choice:** Icon + inline row.

---

## Claude's Discretion

- Specific Material icon choices for key/duration/notes/location.
- Exact OpenAPI `required`/`nullable` marking for the new optional fields.
- Icon-row layout fitting into existing `ListTile.trailing` slots without overflow.
- Whether the password-change form lives on `ProfileScreen` directly or under `SettingsScreen`.

## Deferred Ideas

None — discussion stayed within phase scope. BAND-11 (rotate invite code) and BAND-12 (transfer ownership) are already scoped to Phase 8 per ROADMAP.md.
