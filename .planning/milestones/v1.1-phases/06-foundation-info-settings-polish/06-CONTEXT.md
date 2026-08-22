# Phase 6: Foundation Info & Settings Polish - Context

**Gathered:** 2026-08-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Password change on Profile screen (USER-03), band member count/role display on Bands list + detail (BAND-10), musical key/duration/notes icons on Track list/detail (TRACK-07), location/duration icons on Setlist list/detail (SETL-11). Low-risk display + one form addition; establishes patterns (icon-row display, client-first spec extension) before Phase 7's riskier cache-behavior flip.

</domain>

<decisions>
## Implementation Decisions

### Password Change (USER-03)

- **D-01:** `ChangeUserPasswordRequestBody` in `lib/api/publicapi.yml` currently has only `password` — no `currentPassword` field, but the requirement's acceptance criteria explicitly need "wrong current password → clear rejection." Extend the spec to add a `currentPassword` field (client-first, backend catches up later — same precedent as SETL-12). — **Reversibility:** costly — once backend implements against this field name/shape, renaming means a coordinated client+backend change.
- **D-02:** Form collects current password, new password, and confirm-new-password (three fields), matching the acceptance criteria's UX. Until backend validates `currentPassword`, the field is sent but the server may ignore it — planner/executor should not block on backend support landing first (same graceful-degradation posture as SETL-12's `searchQuery`).

### List-Screen Metadata Gaps (TRACK-07 / SETL-11 / BAND-10)

- **D-03:** `TrackListItem` schema gains **`key`** only (optional/not required) — NOT `notes`. Track list rows get key + duration icons; notes icon is detail-screen-only (full `BandTrack` already has `notes`).
- **D-04:** `SetlistListItem` schema gains **`eventLocation`** (optional/not required, matching the naming already used in `BandSetlist`). Setlist list rows get location + duration icons.
- **D-05:** `BandListItem` schema gains **`ownerId`**. Bands list can then reuse `band_detail_screen.dart`'s existing `_isOwner(currentUserId, ownerId)` comparison against `profileDataProvider` to render a role badge in the list, not just on the detail screen. `membersCount` already exists on `BandListItem` — no change needed for the count half of BAND-10.
- **D-06:** All three spec additions are client-first extensions to `lib/api/publicapi.yml` (mirrors the SETL-12 precedent already set this milestone) — backend implements separately. Fields not yet returned by the server come back absent/null; UI must degrade gracefully (omit the icon) rather than error or show placeholder junk.

### Icon Display Style

- **D-07:** Icon + inline row style — small Material icons sitting inline with tight values (e.g. 🎵 C  ⏱ 3:45  📝) — used consistently across Track list/detail and Setlist list/detail trailing/detail areas. Not icon-only-with-tooltip.

### Claude's Discretion

- Specific Material icon choices for key/duration/notes/location (no icon library preference stated — pick semantically clear standard Material icons, e.g. `Icons.piano` or `Icons.music_note` for key, `Icons.timer`/`Icons.schedule` for duration, `Icons.notes`/`Icons.description` for notes, `Icons.location_on` for location).
- Exact OpenAPI `required`/`nullable` marking for the three new optional fields — model as not-required (omittable), matching the existing optional-field convention already used elsewhere in the spec (e.g. `UpdateBandTrackRequestBody`'s nullable optional fields).
- Layout details for fitting an icon row into existing `ListTile.trailing` slots without overflow on narrow screens.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API Contract
- `lib/api/publicapi.yml` — source of truth; this phase extends `ChangeUserPasswordRequestBody` (+`currentPassword`), `TrackListItem` (+`key`), `SetlistListItem` (+`eventLocation`), `BandListItem` (+`ownerId`). All four are client-first additions — see D-01/D-03/D-04/D-05/D-06.

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — USER-03, BAND-10, TRACK-07, SETL-11 (full acceptance text)
- `.planning/ROADMAP.md` §"Phase 6: Foundation Info & Settings Polish" — success criteria, depends-on, requirements mapping
- `.planning/PROJECT.md` — v1.1 milestone goal, confirms SETL-12 client-first-spec-extension precedent this milestone
- `.planning/STATE.md` — records the SETL-12 precedent decision and the `updateBandTrack`-always-sends-all-fields todo (D-13/Phase 3 note, relevant if password/other update endpoints follow a similar "omitted = keep" convention)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/tracks/track_formatting.dart` — `DurationFormatting.asMinutesSeconds` (mm:ss), `musicalKeys` (24-value key list) — reuse for track duration/key display, no new formatting needed.
- `lib/features/setlists/setlist_formatting.dart` — `DurationFormatting.asMinutesAndSeconds` (words), `pluralizeTracks`, `tracksAndDuration`, `formatEventDate` — reuse for setlist duration/location row composition.
- `lib/features/bands/band_detail_screen.dart`'s `_isOwner(currentUserId, ownerId)` / `_ownershipStatus(profileAsync, ownerId)` static helpers — already handle the tri-state (owner/member/profile-still-loading) logic; reuse directly once `BandListItem.ownerId` exists instead of reimplementing role logic for the list screen.
- `lib/features/auth/login_screen.dart` — existing `TextFormField` + `obscureText: true` + `validator` pattern for password fields; reuse for the new change-password form fields.
- `lib/features/settings/settings_screen.dart` — existing settings sub-screen (currently only theme mode); natural home to consider for the password-change form, or keep it on `ProfileScreen` directly per USER-03's literal wording ("from the Profile screen") — planner's call.
- `lib/api/public_api.dart` — no `changePassword` method yet; follows the existing method pattern (see `register`/`login` for shape: throws `ApiException`, caller catches at UI layer per CLAUDE.md's Error Handling conventions).

### Established Patterns
- List screens (`bands_screen.dart`, `track_list_screen.dart`, `setlist_list_screen.dart`) all use `ListView.separated` + `ListTile` with `trailing` as a `Text`/composed-string widget — icon row addition slots into the existing `trailing` slot.
- Detail screens (`band_detail_screen.dart`, `track_detail_screen.dart`, `setlist_detail_screen.dart`) all follow: `Scaffold` → `SyncStatusBadge` → `_buildContent` reading fields off a `Map<String, dynamic>` from the Riverpod provider. New icon rows slot into `_buildContent`.
- All screens share the `_buildError` retry-button pattern and `isOnlineProvider`-gated mutation actions — no changes needed there for this phase (read-only display work + one new form).

### Integration Points
- New `PublicApi.changePassword({required currentPassword, required newPassword})` method, called from a new/extended screen widget, following the `register`/`login` method shape in `lib/api/public_api.dart`.
- `TrackListItem`/`SetlistListItem`/`BandListItem` schema changes flow through the existing cache-envelope (`lib/cache/cache_service.dart`) transparently — these are additive optional fields, no envelope/cache-key changes needed.

</code_context>

<specifics>
## Specific Ideas

- Icon + inline row visual style, e.g. `🎵 C  ⏱ 3:45  📝` shown together rather than as separate lines or icon-only chips.
- Notes gets no list-screen icon — deliberately detail-only, since `TrackListItem` is not being extended with `notes`.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (BAND-11 rotate-invite-code and BAND-12 transfer-ownership are already scoped to Phase 8 per ROADMAP.md, not this phase.)

</deferred>

---

*Phase: 6-Foundation Info & Settings Polish*
*Context gathered: 2026-08-20*
