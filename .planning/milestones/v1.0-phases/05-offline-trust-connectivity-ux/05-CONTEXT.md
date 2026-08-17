# Phase 5: Offline Trust & Connectivity UX - Context

**Gathered:** 2026-08-17
**Status:** Ready for planning

<domain>
## Phase Boundary

A cross-screen verification and UX pass across every already-built screen (Profile, Home, Bands list/detail, Tracks list/detail, Setlists list/detail): confirm cached data is viewable offline, add a "last synced Xm ago" indicator per screen that escalates to a warning style past ~30 minutes, add a single global offline-mode banner, and visibly disable/block create/update/delete actions while offline. No new screens, no new API endpoints, no offline mutation queue — this phase adds trust signals and guardrails on top of the cache-first architecture Phases 1-4 already built.

</domain>

<decisions>
## Implementation Decisions

### Connectivity detection
- **D-01:** Use `connectivity_plus` for connectivity detection — device radio/interface state (wifi/cellular/none), not an active reachability ping to the API. Accepted tradeoff: a device that reports "connected" via wifi with no real internet (e.g. captive portal) will read as online. — **Reversibility:** costly — **Rationale:** every mutation-blocking control and the global banner wire directly against this signal; swapping to a reachability-based signal later means re-plumbing the same call sites.
- **D-02:** Connectivity state lives in a single global Riverpod provider (a `StreamProvider` wrapping `connectivity_plus`'s `onConnectivityChanged`), watched by the offline banner, every mutation entry point, and reactive form Save buttons — one source of truth, consistent with the existing Riverpod-everywhere pattern from Phases 1-4.
- **D-03:** No debounce on connectivity blips — the banner and mutation-blocking state flip instantly on every `connectivity_plus` event, including sub-second drops (e.g. switching wifi APs). Accepted as reasonable for v1's bounded scope.

### Last-synced timestamp storage
- **D-04:** Every cache write wraps its payload as `{data: {...}, syncedAt: isoString}` instead of storing raw JSON directly — touches every read/write method in `lib/cache/cache_service.dart` (`readProfile`/`writeProfile`, `readHomepage`/`writeHomepage`, `readBands`/`writeBands`, `readBandDetail`/`writeBandDetail`, and the equivalent Tracks/Setlists methods). — **Reversibility:** costly — **Rationale:** rewrites every existing cache read/write call site across all 5 provider files; chosen over a parallel timestamps store specifically to avoid the two-stores-can-drift risk of a separate timestamp box.
- **D-05:** Timestamp granularity is per cache key, not per list/screen — every existing keyed entry (bands list, `band_<id>` detail, tracks list, `track_<id>` detail, setlist list, `setlist_<id>` detail, profile, homepage) gets its own independent `syncedAt`, matching the existing one-entry-per-key cache shape.
- **D-06:** On a silent background-refresh failure (existing Phase 1 D-06 behavior: keep showing cached data, no error surfaced), `syncedAt` is NOT updated — it stays at the last successful write's timestamp, so the staleness indicator stays honest and correctly escalates to the warning style when refreshes keep failing.

### Staleness indicator (per screen)
- **D-07:** The "Synced Xm ago" indicator is one shared widget placed below the AppBar, above screen content — same placement convention on every cached screen (list and detail alike), not inline per list row.
- **D-08:** Warning-style escalation past ~30 minutes stale is a color + icon change only (neutral grey → warning amber/orange) — no copy change, no layout shift.
- **D-09:** The indicator is hidden until 10 minutes have passed since `syncedAt` — freshly-synced screens (under 10 minutes old) show no indicator at all; it appears once data crosses the 10-minute mark and counts up from there, independent of the 30-minute warning escalation in D-08.

### Global offline banner
- **D-10:** The offline-mode banner is a single widget wrapping `RootScaffold`'s body, positioned above the `IndexedStack` content and above the bottom nav — one implementation point that shows/hides on every tab by watching the D-02 connectivity provider, not a per-screen banner instance.

### Mutation blocking
- **D-11:** Create/update/delete entry points (FABs, Save buttons, delete-confirm actions, Join Band, Remove Member) are disabled + visually grayed out while offline — not hidden, not silently tap-blocked. Matches OFFL-03's "visibly disabled or blocked" wording.
- **D-12:** Entry is blocked at the source — the FAB/button that opens a create/edit form is itself disabled while offline, so the user never reaches a form they can't submit (no drafting-while-offline flow, consistent with the read-only-cache, no-mutation-queue scope in PROJECT.md).
- **D-13:** A disabled mutation control gives feedback on tap/long-press — a `Tooltip` reading something like "Requires connection" — rather than staying silently inert.
- **D-14:** If a create/edit form was already open while online and connectivity drops before Save is tapped, the Save button reacts live (disables itself immediately) by watching the same D-02 connectivity provider — no special-casing for controls on an already-open screen.

### Claude's Discretion
- Exact banner copy/styling (color, icon, dismissible or persistent) — left to implementation, should follow Material conventions and the app's existing theme.
- Exact tooltip copy for D-13 beyond "communicates connection is required" — left to implementation.
- Whether the 10-minute-hidden / 30-minute-warning thresholds are defined as shared constants — left to implementation, but both numbers must be used consistently across all screens (not per-screen tuning).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & scope
- `.planning/REQUIREMENTS.md` — OFFL-02 through OFFL-05 (this phase's requirements); OFFL-01/OFFL-06 already validated in Phase 1.
- `.planning/ROADMAP.md` — Phase 5 success criteria (offline viewing, staleness indicator, global banner, mutation blocking, verified across profile/bands/tracks/setlists).
- `.planning/PROJECT.md` — "Constraints" section: read-only cache scope (no offline mutation queue, no conflict resolution — governs D-12's block-at-entry decision); Android/iOS only, web excluded.

### Existing cache & provider architecture (what this phase extends, not replaces)
- `lib/cache/cache_service.dart` — the `_KeyValueStore`/`_HiveStore`/`_InMemoryStore` abstraction and every existing `read*`/`write*` method pair; D-04's wrapper change touches every one of these.
- `lib/providers/profile_provider.dart` — reference implementation of the cache-first pattern (cache hit → background refresh, D-06 behavior on failure) that D-06 above extends with timestamp-preservation semantics.
- `lib/providers/homepage_provider.dart`, `lib/providers/bands_provider.dart`, `lib/providers/tracks_provider.dart`, `lib/providers/setlists_provider.dart` — the other 4 providers following the same cache-first shape; all need the D-04/D-05/D-06 timestamp changes and D-11/D-14 mutation-blocking wiring.
- `.planning/phases/01-foundation-profile-home/01-CONTEXT.md` — D-04 (cache-first loading), D-05 (staleness indicator explicitly deferred to this phase), D-06 (silent background-refresh, no error surfaced), D-07 (offline-with-no-cache empty state), D-10 (Riverpod codegen convention).
- `.planning/phases/02-bands/02-CONTEXT.md`, `.planning/phases/03-tracks/03-CONTEXT.md`, `.planning/phases/04-setlists/04-CONTEXT.md` — establish the per-entity keyed cache pattern (D-05/D-07 in 02-CONTEXT.md) that D-05 above extends with per-key timestamps, and enumerate every existing mutation entry point (create/edit/delete forms, dialogs, FABs) that D-11 through D-14 must cover.

### Navigation & UI integration points
- `lib/navigation/root_scaffold.dart` — the `IndexedStack`-based bottom nav; D-10's global banner wraps this screen's body.

No external specs beyond `publicapi.yml`/`REQUIREMENTS.md`/`ROADMAP.md`/`PROJECT.md` above — this phase adds no new API surface.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/providers/profile_provider.dart`'s cache-first `build()`/`_refresh()`/`_doRefresh()` shape — the pattern every provider's timestamp-aware read/write will extend; `_refresh()`'s catch-and-keep-cached-data path is exactly where D-06's "don't update syncedAt on failure" applies.
- `lib/cache/cache_service.dart`'s `_KeyValueStore` abstraction (`_HiveStore`/`_InMemoryStore`) — the wrap-with-syncedAt change (D-04) is a single change to this shared layer that all 5 provider files inherit, not a per-provider change.

### Established Patterns
- Cache-first loading (Phase 1 D-04): show cached data immediately, refresh in background silently — this phase does not change this flow, only adds a timestamp alongside it and a UI layer reading that timestamp.
- One Hive box per endpoint (Phase 1 D-02), raw decoded JSON, no typed models (Phase 1 D-03) — D-04 changes the JSON shape stored (adds a `syncedAt` wrapper) but keeps the no-typed-model convention; still plain `Map<String, dynamic>` in/out.
- Riverpod codegen (`@riverpod` + `riverpod_generator`) for all providers (Phase 1 D-10) — the new connectivity provider (D-02) follows the same codegen convention.

### Integration Points
- `lib/navigation/root_scaffold.dart` — gains the global offline banner (D-10) wrapping its body.
- Every screen in `lib/features/{profile,home,bands,tracks,setlists}/` — gains the staleness indicator widget (D-07) below its AppBar.
- Every FAB/Save button/delete-confirm/Join-Band/Remove-Member control across `lib/features/bands/`, `lib/features/tracks/`, `lib/features/setlists/` — gains the disabled-while-offline + tooltip treatment (D-11 through D-14).
- `pubspec.yaml` — needs `connectivity_plus` added as a new dependency (D-01).

</code_context>

<specifics>
## Specific Ideas

- The staleness indicator's 10-minute-hidden threshold (D-09) and the 30-minute warning-escalation threshold (D-08) are two independent numbers, not the same threshold reused — don't collapse them into one constant.
- D-01's connectivity_plus choice explicitly accepts the wifi-with-no-internet false-positive as a known v1 gap, not an oversight — don't add reachability-ping logic as a "fix" without it being a deliberate scope change.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope; no new capabilities were proposed during discussion.

### Reviewed Todos (not folded)
None — no pending todos matched this phase (`todo.match-phase` returned 0 matches).

</deferred>

---

*Phase: 5-Offline Trust & Connectivity UX*
*Context gathered: 2026-08-17*
