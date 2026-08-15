# Phase 2: Bands - Context

**Gathered:** 2026-08-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Full band management for the current user: list bands they belong to, create a band, view band detail (name, members, invite code), update a band's name, delete a band (owner only), join another band via invite code, leave a band (self-remove), and remove another member (owner only). Builds on Phase 1's Riverpod + Hive cache-store foundation (cache-first loading, per-endpoint Hive boxes, codegen providers) — no new state-management or caching approach is introduced here, only extended. No Tracks/Setlists screens, no offline-staleness UI (that's Phase 5), no per-member roles beyond owner/member.

</domain>

<decisions>
## Implementation Decisions

### API gap: owner-gating & self-leave
- **D-01:** Build directly against the real `Band.ownerId` and `UserProfile.id` fields from `publicapi.yml` — the backend is considered ready. No username-match fallback, no defensive "missing field" handling. — **Reversibility:** costly — **Rationale:** if the backend turns out not to have shipped these fields when this phase is implemented, every owner-gated UI path and the self-leave flow would need the fallback logic added retroactively across multiple screens.
- **D-02:** Owner-only actions (Delete band, Remove member) are hidden entirely for non-owners — not shown-disabled. Determined by comparing `Band.ownerId` to the current user's id.
- **D-03:** The band owner cannot use "Leave band" — that action is hidden/disabled for them. Owners must delete the band instead; there's no ownership-transfer endpoint, so allowing owner self-removal would orphan the band.
- **D-04:** "Current user id" (for `ownerId` comparisons and self-leave) is read from the existing Phase 1 `profileProvider` (`GET /api/me`, cache-first) — no new network call introduced for this.

### Band list & detail — data & caching
- **D-05:** Bands list row shows name + a placeholder avatar (first-letter circle), matching `BandListItem`'s actual schema (id + name only — no member count/genre, unlike the current mock). Note for future: image avatars are planned for a later milestone — see D-06.
- **D-06:** The avatar is a dedicated reusable widget (e.g. `lib/features/bands/band_avatar.dart`), not inlined into the list tile, so a later phase can swap initials for a real image without touching list/detail screens.
- **D-07:** Both the band list (`bandsBox`) and each viewed band's full detail (members, inviteCode, ownerId) are cached — a per-band keyed cache, following D-02's one-box-per-endpoint pattern from Phase 1 (already anticipated in `01-03`'s generalized `_KeyValueStore` abstraction). Needed so BAND-03 (view band detail) works offline per OFFL-01/02, not just the list.
- **D-08:** Band detail screen follows Phase 1's cache-first pattern (D-04 in `01-CONTEXT.md`): show cached detail immediately if present, then refresh in the background; first-ever view shows loading.

### Create & join band flow
- **D-09:** A single FAB on the Bands list opens an action menu/bottom sheet with "Create band" and "Join with code" — one consistent entry point rather than two separate buttons.
- **D-10:** "Create band" opens a full screen (not a dialog) — consistent with detail/edit screens elsewhere, room to grow if the form gains fields later.
- **D-11:** "Join band" (invite code entry) opens a dialog — matches `JoinBandRequestBody`'s single field.
- **D-12:** After successfully creating or joining a band, the user is navigated straight into that band's detail screen (not back to the list).

### Destructive actions — delete/leave/remove-member
- **D-13:** "Delete band" (owner-only, irreversible, removes it for every member) uses type-to-confirm: the user must type the band's name to enable the Delete button. — **Reversibility:** reversible — **Rationale:** UI-only friction pattern, easy to loosen later if it proves excessive.
- **D-14:** "Leave band" (self-remove) and "Remove member" (owner removing someone else) use a lighter standard Cancel/Confirm dialog with interpolated copy ("Leave [band name]?" / "Remove [username] from [band name]?") — no typing required. Type-to-confirm is reserved for Delete band specifically, since that's the only action that destroys the band for everyone.
- **D-15:** After deleting a band or leaving a band from its detail screen, the user is returned to the Bands list (which reflects the removal).

### Claude's Discretion
- Exact bottom-sheet/menu styling for the FAB's Create/Join action menu (D-09) — left to implementation.
- `BandAvatar` widget's initial-letter rendering details (color, sizing) (D-06) — left to implementation, should follow existing theme.
- Empty-state copy/layout for "no bands yet" on the list screen — not discussed, follow the pattern established in Phase 1 for empty/error states (D-07 in `01-CONTEXT.md`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API contract
- `lib/api/publicapi.yml` — source of truth for all request/response shapes. Relevant for this phase: `GET /api/band/list` → `ListBandsResponseBody` (`items: BandListItem[]`, each `id`+`name` only), `POST /api/band` → `CreateBandRequestBody`/`CreateBandResponseBody`, `GET /api/band/{bandId}` → `Band` (`id`, `name`, `ownerId`, `members: BandMember[]`, `inviteCode`, all required), `PUT /api/band/{bandId}` → `UpdateBandRequestBody`, `DELETE /api/band/{bandId}`, `POST /api/band/join` → `JoinBandRequestBody`, `DELETE /api/band/{bandId}/remove-member/{userId}`. `UserProfile` (`GET /api/me`) has `id` + `username`, both required.

### Project-level constraints
- `.planning/PROJECT.md` — "Constraints" section: reuse existing `ApiClient`/`AuthSession`/`TokenStorage` patterns; offline scope is read-only cache; Android/iOS only, web excluded.
- `.planning/REQUIREMENTS.md` — "API Gaps" section documents the `UserProfile.id`/`Band.ownerId` backend-readiness question resolved by D-01 in this phase; BAND-01 through BAND-09 requirement definitions.
- `.planning/ROADMAP.md` — Phase 2 success criteria and scope boundary (Tracks/Setlists are Phase 3/4, offline staleness UI is Phase 5).

### Prior phase context (established patterns to extend, not re-decide)
- `.planning/phases/01-foundation-profile-home/01-CONTEXT.md` — D-01/D-02/D-03 (Hive-per-endpoint cache pattern), D-04 (cache-first loading), D-06 (silent in-place refresh), D-07 (offline-with-no-cache empty state), D-10 (Riverpod codegen via `riverpod_generator`/`@riverpod`).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/providers/profile_provider.dart` (`profileProvider`) — cache-first `GET /api/me`, already caches `UserProfile.id`; reused directly for current-user-id lookups (D-04) rather than a new fetch.
- `lib/providers/homepage_provider.dart` (`HomepageData`) — the reference implementation of the cache-first pattern (cache hit → return + silent background refresh; cache miss → inline fetch) that the new band-list/band-detail providers should mirror.
- `lib/cache/cache_service.dart` (`CacheService`) — generalized `_KeyValueStore` abstraction (`_HiveStore`/`_InMemoryStore`) already supports adding new boxes; Phase 2 adds `bandsBox` (list) and a per-band detail box/keyed store following the same shape.
- `lib/api/public_api.dart` (`PublicApi`) — currently only has `register`/`login`; band endpoints need new methods here (or a parallel `BandsApi` class) wrapping `ApiClient.send()`.

### Established Patterns
- Cache-first loading (Phase 1 D-04): show cached data immediately, fire background refresh silently, no error surfaced on background-refresh failure.
- One Hive box per endpoint (Phase 1 D-02), raw decoded JSON stored (Phase 1 D-03) — no typed models/TypeAdapters.
- Riverpod codegen (`@riverpod` + `riverpod_generator` + `build_runner`) for all new providers (Phase 1 D-10).
- `ApiException` (statusCode/code/message) caught at the UI layer — same error contract extends to band mutation calls.

### Integration Points
- `lib/features/bands/bands_screen.dart` — currently a `StatelessWidget` with hardcoded `_mockBands`; becomes the cache-first list screen reading from a new bands provider.
- `lib/features/bands/band.dart` — currently a stub model (`name`/`genre`/`memberCount`) that doesn't match the real API schema at all; needs replacing with schema-accurate handling (or removal in favor of raw `Map<String, dynamic>`, per the established D-03 no-typed-model pattern).
- `lib/navigation/root_scaffold.dart` — Bands tab entry point; no changes expected beyond what's already wired.

</code_context>

<specifics>
## Specific Ideas

- Future milestones will add real image avatars for bands — D-06's reusable `BandAvatar` widget exists specifically to make that swap-in painless later. Not built now, just structured for it.

</specifics>

<deferred>
## Deferred Ideas

None beyond the future-avatar note captured in Specifics above — it's a forward-compatibility consideration for this phase's own widget design, not a new capability requiring its own phase.

### Reviewed Todos (not folded)
None — no pending todos matched this phase (`todo.match-phase` returned 0 matches).

</deferred>

---

*Phase: 2-Bands*
*Context gathered: 2026-08-15*
