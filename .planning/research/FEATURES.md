# Feature Landscape: Cadence v1.1 UI Improvements

**Domain:** Flutter band/music collaboration app
**Researched:** 2026-08-20
**Milestone:** v1.1 UI Improvements (7 features)

---

## Table Stakes

Features users expect. Missing = product feels incomplete for a band management app, or blocks alignment with the schema update (fe72e78).

### 1. Change Password Form (POST /api/me/password)

| Criterion | Value |
|-----------|-------|
| Feature | Allow authenticated user to change their account password on Profile screen |
| Why Expected | Any app with authentication requires password change capability; users assume it exists as a security best practice |
| Complexity | **Low-Medium** (form validation, confirmation, error handling) |
| Dependencies | ProfileScreen, existing AuthSession + ApiClient patterns |

**Expected UX (from research):**
- **Fields:** Current password, New password, Confirm password (or show/hide toggle on new password)
- **Validation:** Inline real-time feedback (min 8 chars recommended, no strength reqs unless specified); password visibility toggle to reduce confirm-field friction on mobile
- **Confirmation:** Success toast or inline message after POST completes; error feedback if current password is wrong
- **Anti-pattern to avoid:** "Confirm password" field adds friction without significant error reduction on mobile — Flutter best practice is to use show/hide toggle instead
- **Accessibility:** Error text visible at line-level; password fields have semantic labels

**Notes:**
- Server already has `POST /api/me/password` in schema
- Integration point: new form widget + validation logic in ProfileScreen
- Re-use existing ApiClient error handling (same pattern as login)

---

### 2. Band Member Count + Role Display in Bands UI

| Criterion | Value |
|-----------|-------|
| Feature | Show member count and current user's role (Owner/Member) in band list items and band detail screens |
| Why Expected | Users need to understand band structure, governance, and their permissions within each band; role transparency prevents confusion |
| Complexity | **Low** (read-only display, no interaction) |
| Dependencies | BandsScreen, band list item component, BandDetailsScreen (BandHeader or similar) |

**Expected UX (from research):**
- **Member count display:** Text like "3 members" in band list item or card header
- **Role badge:** Small badge or label next to user's name or in band header, e.g., "Owner" (gold/amber badge) or "Member" (gray/neutral badge)
- **Badge design:** High-contrast color + text (no color-alone encoding), readable over images
- **Accessibility:** Role text always included; badge is decorative support only

**Notes:**
- Server now includes `Band.membersCount` and member `role` (owner/member enum) in schema
- No mutations here; display only
- Helps surface context for feature #3 (UI gate removal) and #4 (owner tools)

---

### 3. Remove Owner-Only UI Gates on Edit/Delete Actions

| Criterion | Value |
|-----------|-------|
| Feature | Lift permission gates on band/track/setlist edit and delete; all members can now mutate (schema allows it) |
| Why Expected | Schema change (fe72e78) loosened permissions; UI must match — users were blocked from edits they can now make |
| Complexity | **Low** (conditional UI removal only, no new logic) |
| Dependencies | BandEditScreen, BandDeleteAction, TrackEditScreen, TrackDeleteAction, SetlistEditScreen, SetlistDeleteAction |

**Expected UX (from research):**
- **No visual change** — edit/delete buttons simply become available to all members
- **Role becomes informational only** — shown via badge (feature #2) but no longer a permission gate
- **Error handling unchanged** — if server rejects a mutation due to permission (unexpected), same error flow as other API failures

**Notes:**
- This is a **breaking change** from v1.0 where only owner could edit/delete
- Does NOT affect access control (server is the authority); just removes client-side gates that were over-restrictive
- Simplifies code: remove `if (band.ownerId == currentUserId)` guards from conditional renders

---

### 4. Owner Tools: Rotate Invite Code & Transfer Ownership

| Criterion | Value |
|-----------|-------|
| Feature | Enable band owner to regenerate invite code (POST /api/band/{bandId}/rotate-invite-code) and transfer ownership to another member (POST /api/band/{bandId}/transfer-ownership) |
| Why Expected | Owners need ability to revoke old invite links and hand off control to another member; these are destructive operations requiring safeguards |
| Complexity | **Medium-High** (multi-step confirmation dialogs, destructive actions, UX safeguards) |
| Dependencies | BandDetailsScreen or BandEditScreen (new "Owner Tools" section), existing ApiClient |

**Expected UX (from research):**

#### Rotate Invite Code
- **Trigger:** Button in band details labeled "Rotate Invite Code" (owner-only, visibility controlled by role check)
- **Confirmation dialog:** Title "Regenerate Invite Code?", body "Anyone with the old code can no longer join. This cannot be undone.", buttons: "Cancel" / "Regenerate"
- **Success:** Display new code in a copyable card (e.g., "New invite code: ABCD1234"); add "Copy to clipboard" button
- **Error handling:** Show toast or dialog if POST fails (network, permission denied)

#### Transfer Ownership
- **Trigger:** Button labeled "Transfer Ownership" (owner-only)
- **Step 1 (selection):** Modal/bottom sheet listing all other band members; user taps to select new owner
- **Step 2 (confirmation):** Confirmation dialog: "Transfer ownership to [Member Name]?", body "You will lose admin access to this band. This cannot be undone.", buttons: "Cancel" / "Transfer"
- **Step 3 (password confirmation):** Request current owner's password (Slack pattern): "Confirm with your password", single TextFormField, "Confirm" button
- **Success:** Toast "Ownership transferred to [Member Name]"; UI updates to show new owner badge; action buttons become read-only
- **Error handling:** Reject non-existent members, deactivated users (server-side validation); show specific error if password fails

**Safeguards (research-backed):**
- Multi-step flow (select → confirm → password) raises friction for destructive action
- Clear messaging ("cannot be undone", "you will lose admin access") sets expectations
- Password confirmation (Slack pattern) adds authentication layer for high-stakes action
- Post-action confirmation (success toast) reduces uncertainty

**Notes:**
- Server has both endpoints in schema (v1.1)
- Password confirmation requires sending current password via POST body; use `currentUserPassword` field
- New invite code should be displayed in a full-screen or bottom-sheet card for easy copying
- Consider "share invite" button (deep link generation) alongside manual copy

---

### 5. Cache Behavior Flip: Online-First with Offline Warning Banners

| Criterion | Value |
|-----------|-------|
| Feature | Change cache-serving logic: online → always fetch fresh; offline → serve cache + warning banner; drop staleness badges entirely |
| Why Expected | User expectations align with online-first (data is fresh by default), and staleness badges created UI clutter (v1.0 problem) |
| Complexity | **Medium** (affects all data providers, cache refresh logic, banner UI) |
| Dependencies | All screens showing cached data (HomeScreen, BandsScreen, TracksScreen, SetlistsScreen, details screens); cache_service, riverpod providers |

**Expected UX (from research):**

#### Online Behavior
- Fetch fresh data on screen load or pull-to-refresh
- No badge or indicator (data is current)
- Small sync spinner in toolbar during fetch (transient, non-blocking)
- Show cached data while fetching (optimistic UI)

#### Offline Behavior
- Serve last-fetched data from cache immediately
- **Warning banner** at top of screen: "You're offline. Showing cached data." (or similar)
- Banner style: Amber/orange background, clear text, non-dismissible (persistent while offline)
- Mutations blocked with offline message (existing behavior preserved)

#### Staleness Tiers (removed)
- **Delete from v1.0:** All `SyncStatusBadge` components
- **Delete from v1.0:** `{data, syncedAt}` envelope display logic (keep envelope for cache logic, just hide from UI)
- **Delete from v1.0:** Staleness thresholds (10 min, 30 min) — no longer needed

**Banner Design (accessibility):**
- High contrast (white text on amber, or dark text on light amber)
- Simple language, no abbreviations
- Optional icon (cloud/wifi icon is redundant if text is clear)

**Notes:**
- Requires updating all data providers to call `.refresh()` on screen load when online (instead of serving cache-hit)
- `isOnlineProvider` already exists (connectivity_plus); reuse it
- Affects cache_service and all `BandNotifier`, `TracksNotifier`, etc. providers
- Testing: Must verify offline banner appears only when `isOnlineProvider` is false

---

### 6. Icons for Metadata Fields (Duration, Musical Key, Notes, Location)

| Criterion | Value |
|-----------|-------|
| Feature | Add Material Design icons to track and setlist list items and detail screens for duration, musical key, notes/description, and location/venue |
| Why Expected | Icons improve scannability and visual hierarchy; music apps (Spotify, Apple Music) use icons to surface key metadata at a glance |
| Complexity | **Low** (visual polish, icon selection, layout tweaks) |
| Dependencies | TrackListItem, TrackDetailScreen, SetlistListItem, SetlistDetailScreen |

**Expected Icon Choices (from research):**

| Metadata | Standard Icon | Rationale |
|----------|---------------|-----------|
| Duration | `Icons.schedule` (clock) | Universally recognized for time/duration |
| Musical Key | `Icons.music_note` (eighth note) | Music-specific, unambiguous in music context |
| Notes/Description | `Icons.description` (document) or `Icons.note` (notepad) | Indicates written content |
| Location/Venue | `Icons.location_on` (pin) or `Icons.public` (globe) | Location-specific; use pin for venues, globe for online events |

**Layout Pattern (from research):**
- Icons appear inline with text or as column headers in list views
- Icon size: 18–24 dp (Flutter Material default)
- Icon color: Secondary/tertiary color (not primary, to avoid visual dominance)
- Text follows icon: "Duration: 3:45" or "Key: C Major"
- Spacing: 8 dp between icon and text (Flutter Material default)

**Notes:**
- No interactions required; icons are decorative labels only
- Existing metadata fields already exist in schema; this is display-only
- Confirm icon colors meet WCAG AA contrast requirements
- Test on both light and dark themes

---

## Differentiators

Features that set Cadence apart. Not expected in all music apps, but valued by power users and bands.

### 7. Setlist Track Picker: Searchable List (Search-as-You-Type)

| Criterion | Value |
|-----------|-------|
| Feature | Replace "add track to setlist" dialog (shows all tracks at once) with a modal searchable list; implement search-as-you-type with debounce over POST /api/track/list with `searchQuery` parameter |
| Why Expected | Band repertoires grow over time; showing all 50+ tracks at once is unusable; search is standard in pickers (Apple Music, Spotify) |
| Complexity | **Medium** (debounce, state management, async search, empty states) |
| Dependencies | SetlistEditScreen, SetlistTracksPicker (new component or refactored existing), existing ApiClient |

**Expected UX (from research):**

#### Search Input
- Text field with placeholder "Search tracks…"
- Clear button (X) visible when text is entered
- Focus and keyboard appear on screen load (optional: auto-focus)

#### Search Behavior
- **Debounce:** 300ms delay before API call (Algolia + Flutter best practice: 150–300ms for autocomplete; 300–500ms for server queries)
- **Empty input:** Show all tracks in band (full list)
- **Typing:** Debounce delay, then call `POST /api/track/list` with `searchQuery` body parameter
- **Results:** List updates immediately when results arrive
- **Loading state:** Spinner or shimmer over list while fetching
- **No results:** Empty state message: "No tracks match 'xyz'. Try different keywords." (e.g., search title/artist)

#### List Display
- Each list item: track title, artist, duration, musical key (icons from feature #6)
- Tap to add to setlist; optional: radio button or checkbox to indicate selected tracks
- Already-added tracks: show checkmark or "Added" badge, disable further selection (or allow re-add with duplicate)

#### Accessibility
- Search input has semantic label
- Loading state announced (aria-live: polite or screen reader text)
- List is scrollable; items are tappable (48 dp minimum touch target)

**Implementation Details (from research):**
- Use `Timer` + cancel pattern or `rxdart.debounceTime()` to implement debounce
- Riverpod family provider: `searchTracksProvider(bandId, searchQuery)` → returns `AsyncValue<List<Track>>`
- On empty search: return cached `_bandTracksProvider` results
- Dispose debouncer on widget disposal to prevent memory leaks

**UX Flow:**
1. User taps "Add tracks" button on SetlistEditScreen
2. Modal opens with search input (auto-focused)
3. User types "Rolling" → debounce fires → API call with `searchQuery: "Rolling"`
4. Results appear: "Rolling Down the River (CCR)", "Rolling Stones Tribute", etc.
5. User taps "Rolling Down the River" → track added to setlist list (dismisses modal or keeps open for multi-add)

**Notes:**
- Server already supports POST /api/track/list with `searchQuery` (v1.1 schema)
- Client must add this to `publicapi.yml` request body if not already present (verify against schema)
- Search is case-insensitive, server-side implementation (client passes query as-is)
- Consider fuzzy matching (soundex, edit distance) if backend supports it; client sends plain query for now
- Could extend to setlist picker similarly in future

---

## Anti-Features

Features to explicitly NOT build in v1.1.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Offline mutation queue / sync-on-reconnect | Out of scope for v1; no conflict resolution strategy defined; adds months of complexity | Keep mutations offline-blocked; v1.2+ will revisit with a proper sync strategy |
| Invite code shareable deep link (auto-clipboard) | Requires deep linking setup + URL scheme registration; out of scope for v1.1 | Provide manual "Copy to clipboard" button; deep linking is future polish |
| Role-based permission gates in UI (e.g., "Owner only" badge on buttons) | Schema no longer supports permission gates; role is informational only | Do not conditionally hide edit/delete/owner-tools buttons based on role |
| Setlist track reorder in picker | Out of scope; reordering happens on the setlist detail screen, not in the picker | Picker is add-only; reordering stays in SetlistEditScreen's existing reorderable list |

---

## Feature Dependencies

```
Feature #1 (Password Change)      → ProfileScreen, AuthSession (logout on 401)
Feature #2 (Member Count + Role)  → Feature #3 (role is informational for removed gates), Feature #4 (owner-only visibility)
Feature #3 (Remove UI Gates)      → All CRUD screens; depends on #2 for display context
Feature #4 (Owner Tools)          → Feature #2 (role check), BandDetailsScreen
Feature #5 (Cache Flip)           → All data providers, all screens (HomeScreen, BandsScreen, TracksScreen, SetlistsScreen, detail screens)
Feature #6 (Icons)                → TrackListItem, SetlistListItem, detail screens (pure display)
Feature #7 (Searchable Picker)    → SetlistEditScreen, ApiClient (POST /api/track/list with searchQuery)

Critical ordering: #5 (cache flip) affects all screens; prioritize early.
                  #2 → #3 → #4 (role display enables owner-gate removal enables owner tools)
                  #1 (independent, ProfileScreen only)
                  #6 (independent, display-only polish)
                  #7 (independent, setlist picker only)
```

---

## MVP Recommendation

Prioritize in this order:

1. **Feature #5 (Cache Flip)** — Foundational change affects all data providers; do first
2. **Feature #2 + #3 (Role Display + Gate Removal)** — Unlock #4; low complexity
3. **Feature #4 (Owner Tools)** — High-value for band admins; medium complexity
4. **Feature #7 (Searchable Picker)** — High-value for usability; medium complexity
5. **Feature #1 (Password Change)** — Security feature, low complexity, any order
6. **Feature #6 (Icons)** — Polish, low complexity, any order

**Rationale:**
- #5 is a prerequisite for all other work (cache logic)
- #2–#3–#4 form a logical block (role system + owner tools)
- #7 is independent but high-impact for UX
- #1 and #6 are low-risk polish and can fill gaps in the schedule

---

## Complexity Notes

| Feature | Estimated LOC | Estimated Days (1 dev, fully tested) | Risk Level |
|---------|---------------|------------------------------------|------------|
| #1 Password Change | 150–200 LOC (form + validation) | 1 day | Low |
| #2 Member Count + Role | 100–150 LOC (display widgets) | 0.5 days | Low |
| #3 Remove UI Gates | 50–100 LOC (remove conditionals) | 0.5 days | Low |
| #4 Owner Tools | 400–600 LOC (dialogs, multi-step flows, password confirm) | 2–3 days | Medium |
| #5 Cache Flip | 300–500 LOC (provider updates, banner UI, cache logic) | 2–3 days | Medium |
| #6 Icons | 100–200 LOC (icon additions to list/detail screens) | 1 day | Low |
| #7 Searchable Picker | 400–500 LOC (debounce, async search provider, empty states) | 2 days | Medium |

**Total estimate:** ~1,500–2,250 LOC, 9–11 days for one developer (includes testing, review, integration).

---

## Screen-Feature Mapping

| Screen | Features Affected | New Components |
|--------|------------------|-----------------|
| ProfileScreen | #1 (password form) | ChangePasswordForm widget |
| BandsScreen | #2 (role badge), #3 (edit/delete enabled) | Minimal changes; role badge in list item |
| BandDetailsScreen | #2 (role display), #3 (edit/delete enabled), #4 (owner tools) | OwnerToolsSection widget (rotate + transfer dialogs) |
| TrackListItem | #3 (edit/delete enabled), #6 (icons) | Icon layout updates |
| TrackDetailScreen | #6 (icons) | Icon layout updates |
| SetlistListItem | #6 (icons) | Icon layout updates |
| SetlistDetailScreen | #6 (icons) | Icon layout updates |
| SetlistEditScreen | #3 (edit/delete enabled), #7 (searchable picker) | SearchableTrackPicker widget (replaces dialog) |
| All data screens (home, bands, tracks, setlists) | #5 (cache flip, banner) | OfflineBanner widget (global or per-screen) |


---

## Sources

- [Sign-in Form Best Practices | web.dev](https://web.dev/articles/sign-in-form-best-practices)
- [Password Advice for Online Forms | Zuko Blog](https://www.zuko.io/blog/password-advice-for-online-forms)
- [Password Field Design Guidelines | Medium](https://medium.com/uxdworld/password-field-design-guidelines-7bd86cfa1733)
- [Transfer Ownership of a Workspace or Org | Slack Help](https://slack.com/help/articles/204401633-Transfer-ownership-of-a-workspace-or-org)
- [Debounce Your Search | Medium](https://medium.com/nerd-for-tech/debounce-your-search-fd270a8042b)
- [Offline UX Design Guidelines | web.dev](https://web.dev/articles/offline-ux-design-guidelines)
- [Designing Offline-First Mobile Apps | Medium](https://kodekx-solutions.medium.com/designing-offline-first-mobile-apps-for-unreliable-networks-6608bfca9d96)
- [Badge UI Design: Notification, Count, and Status Patterns | Setproduct Blog](https://www.setproduct.com/blog/badge-ui-design)
- [Badges: How I Used System Thinking and Research to Evolve a Small But Essential UI element | Medium](https://medium.com/emplifi-design/badges-small-but-essential-ui-element-16699337948b)
- [Flutter Confirmation Dialog: Complete Guide | CopyProgramming](https://copyprogramming.com/howto/how-to-show-confirm-dialog-before-leave-screen-in-flutter)
- [Confirmation Alert Dialog in Flutter | Apps Developer Blog](https://www.appsdeveloperblog.com/confirmation-alert-dialog-in-flutter/)
- [Flutter TextFormField Password Validation | GeeksforGeeks](https://www.geeksforgeeks.org/flutter/flutter-handle-textfield-validation-in-password/)
- [Flutter Search Bar Widgets | GetWidget Blog](https://www.getwidget.dev/blog/flutter-search-bar-widgets/)
- [Debounce Utility in Flutter | Medium](https://medium.com/@valerii.novykov/how-to-create-a-debounce-utility-in-flutter-for-efficient-search-input-cd2827e3bd08)
- [Debounce Sources | Algolia](https://www.algolia.com/doc/ui-libraries/autocomplete/guides/debouncing-sources)
- [Music Metadata Explained | Other Record Labels](https://www.otherrecordlabels.com/ultimate-guide-to-music-metadata)
- [BandLab Band Member Roles | BandLab Help Center](https://help.bandlab.com/hc/en-us/articles/48011428986009-How-do-I-assign-roles-to-my-Band-members)
- [Essential Band Apps for 2026 | Back On Stage](https://backonstageapp.com/blogs/band-management-blog/essential-band-apps-for-bands-and-musicians)
