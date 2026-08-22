# Phase 8: Band Owner Tools - Context

**Gathered:** 2026-08-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Band owner can rotate the band's invite code and transfer ownership to another member, both from the band detail screen. BAND-11 (rotate invite code), BAND-12 (transfer ownership). Non-owner members never see either control. No new capabilities beyond these two owner-gated mutations — this is additive UI + two new API integrations on an existing screen, not a new screen or navigation surface.

</domain>

<decisions>
## Implementation Decisions

### New-owner picker UI

- **D-01:** Transfer starts from a **per-row action** on the existing member list (`band_detail_screen.dart:145-180`), not a separate picker dialog/screen — tapping the action on a specific member's row targets that member directly.
- **D-02:** Each non-owner member row's trailing slot becomes a **`PopupMenuButton`** (overflow menu) holding both "Make owner" and "Remove" — replacing today's standalone `person_remove` `IconButton` (`band_detail_screen.dart:157-177`). "Make owner" uses a distinct icon (e.g. `Icons.workspace_premium` or similar "crown" glyph) from Remove's red destructive styling, signaling a non-destructive action. — **Reversibility:** reversible — purely a trailing-widget swap, no schema/state impact.
- **D-03:** "Remove" keeps its exact existing behavior (opens the unchanged `ConfirmRemoveMemberDialog`) — only its entry point moves from a standalone icon into the new menu. No behavior change to the remove flow itself.

### Transfer confirmation depth

- **D-04:** Single `AlertDialog`, same weight/pattern as `ConfirmRemoveMemberDialog` (`confirm_remove_member_dialog.dart:37-108` is the direct template) — but the body text must **explicitly state the self-effect**: not just "X becomes the new owner" but "You will no longer be the owner of [band]," since transfer is the one owner-tool action that demotes the *acting* user, not just the target.
- **D-05:** Dialog error/loading handling matches `ConfirmRemoveMemberDialog` exactly: `_isSubmitting` spinner in the confirm button, `ApiException.message` shown inline on failure, `isOnline`-gated with a "Requires connection" tooltip when offline, dialog stays open on error rather than closing.

### Rotate invite code UX

- **D-06:** Confirm dialog first — same pattern/weight as the transfer dialog — warning that the current invite code will stop working immediately for anyone who hasn't joined with it yet.
- **D-07:** The existing Invite Code row (`band_detail_screen.dart:189-205`) changes from `[code text] [Copy TextButton]` to **`[code text] [Copy icon] [Rotate icon]`** — both actions become `IconButton`s. Rotate uses a circular-arrow ("refresh"-style) icon. Rotate is owner-gated (hidden/disabled for non-owners); Copy stays visible to everyone as today.
- **D-08:** On successful rotate, `RotateBandInviteCodeResponseBody.newInviteCode` is used to **patch the row in place** (mirrors `updateName()`'s local-patch pattern, `bands_provider.dart:247-255`) — the code text swaps immediately, plus a snackbar confirms "Invite code rotated." No dependency on a background refetch to see the new code.

### Post-action state & landing

- **D-09:** `TransferBandOwnership`'s `200` response has no body (`publicapi.yml:268-286`) — unlike rotate, there is no server-returned value to trust for an optimistic local patch. On success, **invalidate and refetch** `bandDetailDataProvider(bandId)` (`ref.invalidate(...)`, same call `ConfirmRemoveMemberDialog` already makes at `confirm_remove_member_dialog.dart:50`) rather than patching `ownerId` client-side from the known target `userId`.
- **D-10:** The Bands-tab list screen (`bands_screen.dart:141-153`) also renders an Owner/Member badge per band, sourced from the separate `BandsListData` cache — which, under Phase 7's online-first model, only refetches on tab-switch (Phase 7 D-01). Left unpatched, a user who transfers ownership and pops straight back to the Bands tab (without a tab-switch in between) would see a stale "Owner" badge. **Also patch `bandsListDataProvider`'s matching band entry** after a successful transfer, mirroring `renameBand()`'s in-place list-patch pattern (`bands_provider.dart:141-152`), using the known target `userId` as the new `ownerId` for that list entry specifically (the list-side patch is safe to do optimistically even though the detail-side D-09 refetches, since the transfer already succeeded server-side by that point).
- **D-11:** Rotate does **not** need an equivalent list-side patch — `BandListItem` (`publicapi.yml:761-778`) has no `inviteCode` field, so `BandsListData` never displays it.
- **D-12:** Both actions resolve **in place on `band_detail_screen`** — dialog closes, screen re-renders (updated invite code, or demoted owner-controls state) with no navigation. Matches `ConfirmRemoveMemberDialog`/`ConfirmDeleteBandDialog`'s existing pattern; only Delete navigates away today, since the band itself is gone in that case.

### Claude's Discretion

- Exact Material icon for "Make owner" (e.g. `Icons.workspace_premium`) and for Rotate's circular-arrow icon (e.g. `Icons.refresh` / `Icons.autorenew`) — no specific icon mandated beyond "crown-like, distinct from red destructive Remove" and "circular arrow," per D-02/D-07.
- `PopupMenuButton` internal structure/styling (menu item icons, dividers) — mechanical Flutter widget choice, no design decision attached.
- Whether `BandDetailData`'s existing `_version` monotonic-counter guard (`bands_provider.dart:171-176`, mirrored per-family) needs a bump inside the new rotate-patch and transfer-invalidate methods — same pattern as `updateName()`'s existing `_version++`; planner/executor's call on the exact wiring, but the guard itself must be preserved per the established Phase 2/6/7 precedent (see PROJECT.md Key Decisions).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API Contract
- `lib/api/publicapi.yml:250-286` — `RotateBandInviteCode` (POST `/api/band/{bandId}/rotate-invite-code`, returns `RotateBandInviteCodeResponseBody.newInviteCode`) and `TransferBandOwnership` (POST `/api/band/{bandId}/transfer-ownership`, body `TransferBandOwnershipRequestBody.userId`, `200` with no response body). No schema changes needed this phase — both endpoints already exist in full.
- `lib/api/publicapi.yml:761-778` — `BandListItem` schema (no `inviteCode` field — informs D-11).
- `lib/api/publicapi.yml:796-830` — `Band`/`BandMember`/`BandMemberRole` schemas (`ownerId`, `members[].id/username/role`).

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — BAND-11, BAND-12 (full acceptance text)
- `.planning/ROADMAP.md` §"Phase 8: Band Owner Tools" — success criteria (4 criteria: rotate shows new copyable code immediately, old code stops working, transfer flow flips owner-only controls for both parties, non-owners never see either control), depends-on Phase 7
- `.planning/PROJECT.md` — v1.1 milestone goal; Key Decisions table documents the `_version` monotonic-counter guard pattern (Phase 2) and the "always send all editable fields on update" convention (Phase 3) — the latter doesn't apply here since neither endpoint is a partial-update PUT/PATCH
- `.planning/STATE.md` — flagged Phase 8 for deeper phase-research before planning (`_version` guard interaction, multi-step destructive-action UX, profile-invalidation-on-transfer) — this discussion resolved the destructive-action-UX question (D-04/D-05) and the invalidation question (D-09/D-10); the `_version` guard wiring itself is left to research/planning per Claude's Discretion above
- `.planning/research/SUMMARY.md` — original draft flagged "password confirmation (Material showDialog)" for owner tools; **not applicable** — `TransferBandOwnershipRequestBody` (publicapi.yml:861-868) has no password field, only `userId`, so no password-confirmation step is being built

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/features/bands/confirm_remove_member_dialog.dart` (full file, 109 lines) — the direct template for both the new transfer-confirm and rotate-confirm dialogs: `_isSubmitting`/`_errorMessage` state, `ApiException` catch pattern, `isOnline`-gated `FilledButton` with tooltip, dialog-stays-open-on-error behavior.
- `lib/features/bands/band_detail_screen.dart` — `isOwner`/`ownershipStatus` static helpers (lines 30-44) already implement the tri-state owner check this phase reuses as-is for gating both new controls; member-list rendering (lines 145-180) is where the `PopupMenuButton` slots in; Invite Code row (lines 182-205) is where Copy/Rotate icons slot in.
- `lib/providers/bands_provider.dart` — `BandDetailData.updateName()` (lines 247-255) is the direct template for the rotate local-patch (D-08); `BandsListData.renameBand()` (lines 141-152) is the direct template for the transfer list-patch (D-10). Both already show the `_version++` + `state = AsyncData(...)` + cache-write + `SyncedAt`-bump shape to replicate.
- `lib/features/bands/confirm_delete_band_dialog.dart` — secondary reference for an owner-only destructive-styled dialog, though `ConfirmRemoveMemberDialog` is the closer template since it (like transfer) doesn't navigate away on success.

### Established Patterns
- Every owner-gated action on this screen follows: `Tooltip(message: isOnline ? '' : 'Requires connection', child: <control disabled when !isOnline>)`, wrapping either a `ListTile` or an `IconButton` — both new controls (Make-owner menu item, Rotate icon) must follow this exact gating shape.
- `PublicApi` methods (`lib/api/public_api.dart`) all follow: named required params, throws `ApiException` on failure, caller catches at the UI/dialog layer — new `rotateInviteCode(bandId)` and `transferOwnership({bandId, userId})` methods follow `removeMember`'s shape (`public_api.dart:131-140`) most closely (band-scoped, no response body to parse for transfer; simple response parse for rotate, similar to `createBand`'s shape at `public_api.dart:85-98`).

### Integration Points
- New `PublicApi.rotateInviteCode(String bandId)` and `PublicApi.transferOwnership({required String bandId, required String userId})` methods in `lib/api/public_api.dart`.
- New `BandDetailData` methods (rotate local-patch) in `lib/providers/bands_provider.dart`, called from the new rotate-confirm dialog.
- `BandsListData` gains a new method (transfer list-patch, D-10) alongside `renameBand()`, called from the new transfer-confirm dialog after the `bandDetailDataProvider` invalidation succeeds.

</code_context>

<specifics>
## Specific Ideas

- Row layout for member actions: "make them both icons, the copy icon and rotate icon (little arrow circle)" — user's own words, captured verbatim in D-07 (circular-arrow icon for Rotate, replacing the Copy `TextButton` with a `Copy` `IconButton` too).
- Transfer dialog body must name the self-effect explicitly ("You will no longer be the owner"), not just describe what happens to the target member (D-04).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Homepage quick actions and the searchable setlist track picker are already scoped to Phases 9-10 per ROADMAP.md, not this phase.)

</deferred>

---

*Phase: 8-Band Owner Tools*
*Context gathered: 2026-08-21*
