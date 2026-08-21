# Phase 7: Cache Behavior Flip — Online-First - Context

**Gathered:** 2026-08-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Flip all 10 Riverpod data providers (Profile, Homepage, BandsList, BandDetail, TracksList×2, TrackDetail, SetlistsList×2, SetlistDetail) from cache-first (serve cache instantly + silent background refresh) to online-first (online → always fetch fresh; offline → serve cache with a persistent warning). Remove the `SyncStatusBadge`/staleness-tier widget system entirely (10 call-sites). OFFL-07 (online always fresh), OFFL-08 (offline banner + badge removal). No new capabilities — this is a behavior-model swap over existing screens, not new UI surfaces.

</domain>

<decisions>
## Implementation Decisions

### Fresh-on-open trigger

- **D-01:** The 5 IndexedStack tab screens (Home, Bands, Tracks, Setlists, Profile) stay alive across tab switches — providers only `build()` once per app session under the current architecture. To satisfy OFFL-07's "always shows freshly-fetched data on open" literally, refetch must be wired to fire on **every tab switch**, not just cold start. Needs a tab-visibility trigger (e.g. reacting to `selectedTabIndexProvider`), not just a `build()`-time check. — **Reversibility:** reversible — purely additive listener logic.
- **D-02:** Band/Track/Setlist detail screens need **no new wiring** for this. They're pushed routes backed by `autoDispose` family providers, which already rebuild fresh on every `Navigator.push`. Only the 5 tab screens need the new tab-switch-refetch mechanism.

### Online-but-fetch-fails fallback

- **D-03:** `isOnlineProvider` (connectivity_plus) can report online while a fetch still fails (DNS blip, server down, timeout). On any fetch failure — online-first attempt or true offline — **fall back to the existing cache silently** if one exists, same code path as true-offline. Do not surface a distinct "couldn't refresh" error when cache is available.
- **D-04:** The banner wording becomes **connectivity-agnostic**: reword from "You're offline — showing cached data" to something like "Showing cached data — may be out of date," since it can no longer honestly claim the device is offline once it also covers the fetch-fails-while-online case in spirit.
- **D-05:** Despite D-04's wording change, the banner's **trigger condition stays exactly `isOnlineProvider`** (device-level connectivity) — it does NOT become per-screen or aggregate-across-screens aware. This is a deliberate accepted tradeoff: the online-but-fetch-failed edge case (D-03) silently serves cache with **no banner at all** in that case. Simplicity of one global `RootScaffold`-level widget was chosen over per-screen accuracy. Do not build a per-screen or OR'd-across-providers banner variant.

### Offline + no-cache state

- **D-06:** A screen opened offline with nothing ever cached for it (fresh install, first-ever visit while offline) gets a **dedicated offline-empty state**: "No cached data — connect to the internet to load this" + a cloud-off-style icon, reusing the existing `_buildError` layout shell but with offline-specific copy/icon instead of the generic "Couldn't load X" message. **No Retry button** on this state (retrying does nothing while offline).
- **D-07:** Recovery from the no-cache state is **automatic**: the screen listens to `isOnlineProvider`, and the instant it flips to online, it refetches on its own — no user action (no manual pull-to-refresh needed) required to escape the empty state.

### In-flight fetch loading UX

- **D-08:** When a refetch is in flight and the provider's state already holds cached content (tab-switch refetch, or any refetch after the first successful load), **keep the old content visible** and show a subtle refresh indicator (e.g. thin top progress bar or an `AppBar` spinner) rather than blanking the screen. Content swaps in place when the fresh fetch lands. This avoids a blank-flash on every tab switch.
- **D-09:** **Cold start is the one exception**: when state has no data yet at all (true first-ever fetch this session, nothing cached), the screen still shows today's full-screen centered spinner (the standard `AsyncValue.when()` loading branch). The subtle-indicator behavior (D-08) only applies once there is something in state to keep showing — including the very first tab-switch-triggered refetch that happens right after cold start completes.

### Claude's Discretion

- Exact mechanism for wiring "every tab switch" refetch (D-01) — e.g. listening to `selectedTabIndexProvider` from each screen, or a shared mixin/helper across the 5 tab screens. Planner/researcher's call given the existing `navigation_provider.dart` shape.
- Exact widget/icon choice for the subtle in-flight refresh indicator (D-08) and the offline-empty-state icon (D-06) — no specific Material icon or widget mandated beyond "thin progress bar or AppBar spinner" / "cloud-off-style icon."
- Whether the per-resource `XxxSyncedAt` providers (`ProfileSyncedAt`, `BandsListSyncedAt`, etc.) are kept, repurposed, or removed once `SyncStatusBadge` is deleted — they may still be useful internally for the "am I currently serving cache" logic behind D-03/D-08, but nothing in this discussion requires a user-visible "last synced" timestamp anywhere.
- Precise `SyncStatusBadge` removal mechanics across its 10 call-sites — mechanical deletion, no design decision attached; no replacement text/badge is required by the roadmap's success criteria.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API Contract
- `lib/api/publicapi.yml` — source of truth; this phase makes no schema changes (pure client-side cache-behavior change), but endpoints hit by the 10 providers must not change shape.

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — OFFL-07, OFFL-08 (full acceptance text)
- `.planning/ROADMAP.md` §"Phase 7: Cache Behavior Flip — Online-First" — success criteria, depends-on (Phase 6), requirements mapping
- `.planning/PROJECT.md` — v1.1 milestone goal; Key Decisions table documents the existing `_version` monotonic-counter guard pattern (Phase 2) that online-first fetches must continue to respect
- `.planning/STATE.md` — flags Phase 7 for deeper phase-research before planning (`_version` guard interaction, offline banner accessibility, multi-step destructive-action UX are called out — the destructive-action item is Phase 8's, not this phase's)
- `.planning/research/SUMMARY.md` §"Phase 3: Cache-Behavior Flip" (old draft numbering — now Phase 7) — original architecture sketch (superseded in parts by this discussion's D-04/D-05 banner decision, which rejected the draft's per-screen/OR'd banner ideas in favor of keeping the global widget simple)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/widgets/offline_banner.dart` — the persistent banner (OFFL-08) **already exists** as a global `RootScaffold`-level widget, driven by `isOnlineProvider`. This phase only needs to reword its text (D-04) — the widget itself, its placement, and its trigger condition (D-05) all stay as-is.
- `lib/providers/connectivity_provider.dart` (`isOnlineProvider`) — existing connectivity signal, already consumed by ~19 files; reuse directly for D-03/D-05/D-07's online-check and reconnect-listener needs.
- `lib/providers/navigation_provider.dart` (`selectedTabIndexProvider`) — existing tab-index state; the natural hook point for D-01's tab-switch-refetch trigger.
- `lib/cache/cache_service.dart` — Hive-backed `{data, syncedAt}` envelope, unchanged by this phase; every provider's `readX()`/`writeX()`/`readXSyncedAt()` calls stay as they are, only the *policy* around when to prefer cache vs. fetch changes.
- All 10 providers already have a monotonic `_version` int guard (`bands_provider.dart`, `tracks_provider.dart`, `setlists_provider.dart`) or none where mutation races don't apply (`profile_provider.dart`, `homepage_provider.dart` are read-mostly) — this guard must be preserved/reused when reworking `_refresh()`/`_doRefresh()` into the new online-first flow so a slow fetch can't clobber a local mutation.

### Established Patterns
- Every provider currently follows the identical shape: `build()` reads cache → if hit, return cached + `unawaited(_refresh())`; if miss, `_fetchAndCache()` inline (any `ApiException` → `AsyncError` → "Couldn't load X" + Retry). This entire shape is what's being inverted per-provider: online-first checks `isOnlineProvider` before deciding cache-vs-fetch-first, rather than always preferring cache.
- List screens (`bands_screen.dart`, `track_list_screen.dart`, `setlist_list_screen.dart`) use `AsyncValue.when()` off their provider directly for loading/error/data branches — D-08/D-09's "keep old content, subtle indicator vs. full-screen spinner" distinction will need a state shape that can express "have data AND currently refreshing" (today's `AsyncValue` conflates "no data yet" and "refreshing" into the same `isLoading` bucket when a manual `state = AsyncLoading()` is used, so `_doRefresh()` cannot naively set that without checking `state.hasValue` first — see `_doRefresh()`'s existing `if (state.value == null)` guard pattern in every provider as the template).
- `lib/widgets/sync_status_badge.dart` — the widget being removed, currently instantiated in: `setlist_detail_screen.dart`, `setlists_screen.dart`, `setlist_list_screen.dart`, `profile_screen.dart`, `home_screen.dart`, `tracks_screen.dart`, `bands_screen.dart`, `band_detail_screen.dart`, `track_list_screen.dart`, `track_detail_screen.dart` (10 files).

### Integration Points
- `lib/navigation/root_scaffold.dart` — hosts the single global `OfflineBanner` above the `IndexedStack`; D-05 confirms no structural change here, only `offline_banner.dart`'s internal text (D-04).
- Each of the 5 tab screens will need new logic reacting to `selectedTabIndexProvider` (D-01) to trigger a refetch when they become the visible tab — this is new integration surface not present in any provider today.

</code_context>

<specifics>
## Specific Ideas

- Banner copy direction: something like "Showing cached data — may be out of date" (exact final copy left to planner/executor, but must not claim "you're offline" literally since it also silently covers stale-cache-while-technically-online in spirit, per D-04).
- Offline-empty-state copy direction: "No cached data — connect to the internet to load this" (exact final copy left to planner/executor).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Owner tools, homepage quick actions, and the searchable track picker are already scoped to Phases 8–10 per ROADMAP.md, not this phase.)

</deferred>

---

*Phase: 7-Cache Behavior Flip — Online-First*
*Context gathered: 2026-08-21*
