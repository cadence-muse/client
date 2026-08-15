# Phase 2: Bands — API Coverage Decision

**Generated:** 2026-08-15
**Trigger:** `api-coverage` planner contribution hook fired (phase integrates `lib/api/publicapi.yml`'s `Bands` tag surface).
**Policy:** Full API Coverage by Default — every capability under the `Bands` tag is `INTEGRATE` unless explicitly opted out with a reason.

## Bands Tag — Full Capability Surface

| Capability | Endpoint | Requirement | Disposition | Plan |
|------------|----------|-------------|-------------|------|
| List current user's bands | `GET /api/band/list` | BAND-01 | INTEGRATE | 02-01 |
| Create a new band | `POST /api/band` | BAND-02 | INTEGRATE | 02-03 |
| Get detailed band info (name, members, ownerId, inviteCode) | `GET /api/band/{bandId}` | BAND-03 | INTEGRATE | 02-02 |
| Update band info (name) | `PUT /api/band/{bandId}` | BAND-04 | INTEGRATE | 02-04 |
| Remove (delete) band — owner only | `DELETE /api/band/{bandId}` | BAND-05 | INTEGRATE | 02-05 |
| Join a band by invite code | `POST /api/band/join` | BAND-06 | INTEGRATE | 02-03 |
| View + copy invite code (field on `Band`) | part of `GET /api/band/{bandId}` | BAND-07 | INTEGRATE | 02-02 |
| Remove band member — self (leave) | `DELETE /api/band/{bandId}/remove-member/{userId}` | BAND-08 | INTEGRATE | 02-05 |
| Remove band member — other (owner action) | `DELETE /api/band/{bandId}/remove-member/{userId}` | BAND-09 | INTEGRATE | 02-05 |

**No OPT-OUTs.** Every `Bands`-tag capability maps 1:1 to a locked BAND-01..09 requirement (REQUIREMENTS.md) and is built.

## Adjacent tags in the same OpenAPI file (not part of this decision)

`lib/api/publicapi.yml` also defines `track` and `setlist` sub-resource endpoints under `/api/band/{bandId}/track/*` and `/api/band/{bandId}/setlist/*`. These are **not** Bands-tag capabilities being opted out of here — they are separate resource families explicitly owned by later phases per `ROADMAP.md` (Phase 3: Tracks, Phase 4: Setlists) and REQUIREMENTS.md's TRACK-*/SETL-* requirement groups. Listed for completeness, not as a Phase 2 opt-out.

## Known API contract gap discovered during planning (not a coverage opt-out)

`POST /api/band/join` (`JoinBand`) returns `'200': description: Success` with **no response schema** — it does not return the newly-joined band's id. D-12 (CONTEXT.md) requires navigating straight to the joined band's detail screen after a successful join. Since inventing a field is prohibited, Plan 02-03 resolves this via a client-side list-diff technique (capture band-id set before join, refetch fresh list after join, diff to find the new id) with an explicit fallback (return to Bands list instead of guessing) if the diff is ambiguous. See `02-03-PLAN.md` Task 2 and the "Flagged Assumptions" note there.
