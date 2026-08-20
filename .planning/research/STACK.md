# Technology Stack: v1.1 UI Improvements

**Project:** Cadence (Flutter mobile app for band repertoire management)  
**Milestone:** v1.1 UI Improvements  
**Researched:** 2026-08-20  
**Confidence:** HIGH (all technologies already validated in v1.0 production app; research focuses on v1.1 feature-specific additions only)

## Verdict: Zero New Dependencies Required

All v1.1 features can be implemented using the validated, shipped v1.0 stack. No package additions are needed.

---

## Current Stack (v1.0, Already Shipping)

### Core Framework
| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| Flutter | ^3.12.2 | Mobile/web framework | ✓ Shipping Android/iOS |
| Dart | ^3.12.2 | Language runtime | ✓ Current stable |
| flutter_riverpod | 2.6.1 | State management | ✓ Proven end-to-end in v1.0; AsyncNotifiers, family providers, disposal hooks working |
| riverpod_annotation | 2.6.1 | Codegen annotations | ✓ @riverpod macro support for AsyncNotifier |

### HTTP & Authentication
| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| http | 1.6.0 | REST API client | ✓ ApiClient wraps this; auth header attachment, 403 auto-logout working |
| flutter_secure_storage | 11.0.0 | Secure token persistence | ✓ Token persists across restarts; tested on Android/iOS |

### Offline Cache
| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| hive | 2.2.3 | Local key-value store with nested-collection support | ✓ CacheService wraps this; 5 boxes (profile, homepage, bands, tracks, setlists) with {data, syncedAt} envelope |
| hive_flutter | 1.1.0 | Hive platform integration | ✓ Platform scaffolding; native libs auto-loaded |
| connectivity_plus | 7.3.1 | Online/offline detection | ✓ isOnlineProvider wired throughout; mutations gated on connectivity |

### UI & Icons
| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| cupertino_icons | 1.0.8 | Icon font (iOS-style) | ✓ In use; complemented by Material Icons |
| Material Icons (built-in) | Flutter SDK | Material Design icons (4264+) | ✓ Available via Icons class; no extra package needed |

### Testing & Linting
| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| flutter_test | SDK | Testing framework | ✓ 284 tests passing in v1.0 |
| flutter_lints | 6.0.0 | Lint rules | ✓ Zero violations; `flutter analyze` passes |

---

## v1.1 Feature Integration: What Stays, What Changes

### Feature 1: Password Change Form (`POST /api/me/password`)

**Stack Additions:** None.

**Implementation:**
- **API layer:** Add `changePassword(oldPassword, newPassword) → Future<void>` method to `PublicApi`, wrapping existing `ApiClient.post()`
- **UI:** Stateful form on ProfileScreen with `TextField` widgets (Flutter built-in)
- **Error handling:** Reuse existing ApiException pattern; 400/401/403 codes have specific messages
- **State:** Use Riverpod FutureProvider to track loading/error state

**Why no new dependencies:**
- Form validation built-in via `TextFormField`
- ApiClient already handles POST; no changes needed
- ApiException already parses error responses
- Riverpod provides loading/error/data states

---

### Feature 2: Band Member Count + Role Display

**Stack Additions:** None.

**Implementation:**
- **Data model:** Schema (fe72e78) now includes `Band.membersCount` and member `role: "owner" | "member"` enum
- **Deserialization:** Update Band model's `fromJson()` to parse these fields (already in publicapi.yml)
- **UI:** Display in BandsScreen list tile and band detail; use existing theme text styles

**Why no new dependencies:**
- Data already available in API response
- UI is plain text display; no special widgets needed

---

### Feature 3: Remove Owner-Only UI Gates; Add Owner Tools

**Stack Additions:** None.

**Implementation:**
- **Schema changes:** Endpoints relax from owner-only mutations to any-member mutations; new POST endpoints for invite rotation and ownership transfer
- **API layer:** Add `rotateInviteCode(bandId) → Future<Band>` and `transferOwnership(bandId, newOwnerId) → Future<Band>` to PublicApi
- **UI logic:** Gate owner-only actions on `Band.ownerId == currentUser.id` check; show confirmation dialogs before destructive operations
- **State:** Wire Riverpod notifiers to refetch band data after mutations

**Why no new dependencies:**
- Conditional rendering: Flutter's `if` statements and ternary operators
- Dialogs: `showDialog()` built-in to Material
- Mutations: Existing ApiClient + Riverpod pattern

---

### Feature 4: Cache Behavior Flip — Online-Fresh / Offline-Cached

**Stack Additions:** None; **major refactor of CacheService**.

**Current (v1.0):**
- CacheService stores `{data, syncedAt}` envelope
- UI displays staleness badge (10min/30min thresholds) on every screen
- Mutations blocked while offline

**New (v1.1):**
- **Online:** Always fetch fresh from server; bypass cache entirely
- **Offline:** Serve cached data with warning banner ("You are offline — data may be outdated")
- **Removes:** SyncStatusBadge widget, staleness thresholds, per-screen sync logic

**Implementation:**
1. **CacheService.get():** Check `isOnline` (from connectivity_plus) before deciding behavior
   ```dart
   if (isOnline) {
     // Fetch fresh, update cache, return new data
     final fresh = await fetchFromServer();
     await cache.write(key, fresh);
     return fresh;
   } else {
     // Return cached or error if empty
     return cache.read(key) ?? throw CacheEmptyError();
   }
   ```

2. **Riverpod providers:** Simplify from checking `syncedAt` timestamps to checking `isOnline` flag
   - Before: `if (cacheTime.difference(now) > 10mins) refetch()`
   - After: `if (!isOnline) serveCached(); else fetchFresh()`

3. **UI:**
   - Remove all staleness indicators from screens
   - Add global offline banner at RootScaffold level using `MaterialBanner` or persistent `SnackBar`
   - Keep mutations gated on `isOnline` (already working)

4. **Hive envelope:** Retain `{data, syncedAt}` in storage for potential v1.2 smart sync, but stop *using* syncedAt for staleness decisions

**Why no new dependencies:**
- Binary online/offline check: Already have `connectivity_plus`
- Cache bypass logic: Existing CacheService.get() can be extended with conditional
- Offline banner: Flutter's `MaterialBanner` or `SnackBar` (built-in)
- Removal of staleness logic: Pure refactor; no new pattern needed

**Why this is safe:**
- Offline detection proven in v1.0 via `connectivity_plus`
- Cache layer proven in v1.0 (25,000+ LOC tested, 284 tests passing)
- Removing staleness logic *simplifies* the codebase (removes one state dimension)
- No API changes; no schema updates needed

---

### Feature 5: Icons for Metadata (Location, Duration, Musical Key, Notes)

**Stack Additions:** None.

**Implementation:**
- **Icon choices (all Material Design, built-in):**
  - Location: `Icons.location_on` or `Icons.place`
  - Duration: `Icons.timer` or `Icons.schedule`
  - Musical key: `Icons.music_note` (or `Icons.key`, `Icons.music_note_outlined`)
  - Notes: `Icons.notes` or `Icons.description`

- **UI placement:** Track detail/list screens and Setlist detail/list screens
- **Styling:** Use `Theme.of(context).iconTheme.color` for light/dark mode consistency

**Why no new icon package:**
- Flutter's Material Icons provides 4264+ icons (as of 2026-08-20)
- All needed metadata icons are built-in with multiple variants (outlined, filled, rounded, sharp)
- `cupertino_icons` (already included) provides iOS variants
- No dependency bloat; use what ships with Flutter

---

### Feature 6: Setlist Track Picker — Searchable List (Replace Dialog)

**Stack Additions:** None; **use Riverpod's native debounce pattern**.

**Current:** Bottom-sheet dialog with flat list of tracks.

**New:** Full-screen searchable list with search-as-you-type, optional server-side filtering.

**Implementation:**

1. **UI Components:**
   - `TextField` for search input (Flutter built-in)
   - `ListView` of Track tiles with checkbox or tap-to-select
   - Replace existing bottom-sheet dialog

2. **Riverpod state:**
   - Create `searchQueryProvider = StateProvider<String>((ref) => '')`
   - Create `filteredBandTracksProvider = FutureProvider.family<List<Track>, String>((ref, bandId) async { ... })`

3. **Debounce using Riverpod's native `ref.onDispose()`:**
   ```dart
   @riverpod
   Future<List<Track>> filteredBandTracks(Ref ref, String bandId) async {
     var cancelled = false;
     ref.onDispose(() => cancelled = true);
     
     // Debounce: wait 300ms before fetching
     await Future.delayed(const Duration(milliseconds: 300));
     if (cancelled) throw Exception('Cancelled/debounced');
     
     // Fetch or filter
     final query = ref.watch(searchQueryProvider);
     return await ref.watch(publicApiProvider).bandTracks(
       bandId,
       searchQuery: query, // Optional—backend provides this in later update
     );
   }
   ```

4. **Widget binding:**
   - TextField updates `searchQueryProvider`
   - ListView watches `filteredBandTracksProvider`
   - Rebuilds happen automatically as provider changes (debounce in provider logic)

5. **Client-side fallback (v1.1):**
   - If server hasn't yet added `searchQuery` param to `ListBandTracks`, filter locally:
     ```dart
     List<Track> filtered = tracks
       .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
       .toList();
     ```

**Why no new debounce package:**
- Riverpod's `ref.onDispose()` + `Future.delayed()` provides native debounce without external dependencies
- Pattern documented in official Riverpod guide: [riverpod.dev/docs/how_to/cancel](https://riverpod.dev/docs/how_to/cancel)
- Already used in v1.0 codebase for cleanup (e.g., `ref.onDispose()` in AsyncNotifiers)
- Keeps bundle lean and self-contained

**Why no new list UI library:**
- `ListView` (built-in) sufficient for this use case
- No need for `flutter_typeahead` or `search_tiles`
- Checkbox or tap-to-select via `GestureDetector` or `ListTile.onTap` (built-in)

---

## Alternatives Considered

| Feature | Proposed Addition | Recommended | Why Not |
|---------|-------------------|-------------|---------|
| Search debounce | Add `throttle_debounce` package | ✓ Use Riverpod's native `ref.onDispose()` | External package not needed; pattern already in v1.0 codebase; keeps dependencies lean |
| Metadata icons | Add `font_awesome_flutter` or `material_design_icons_flutter` | ✓ Use built-in Material Icons | Flutter's Icons class has 4264+ icons; all needed metadata icons are built-in |
| Form validation | Add `form_validator` package | ✓ Use Flutter's `TextFormField` + validator callbacks | Built-in validators cover most needs; custom validator lambdas handle special cases |
| Offline banner | Add overlay or UI component library | ✓ Use Flutter's built-in `MaterialBanner` or `SnackBar` | Both are Material design standard; no special library needed |
| Cache simplification | Keep staleness-badge system + add online/offline toggle | ✓ Remove staleness logic entirely | Online-first/offline-cached is simpler mental model; removes one state dimension; easier to test and reason about |

---

## Stack Installation

**No new packages to add.** Existing pubspec.yaml is complete for v1.1 features.

Verify the current setup:
```bash
flutter pub get
flutter analyze
flutter test
```

---

## Integration Checklist

- [ ] **Password change:** Add `changePassword()` to PublicApi; wire form on ProfileScreen
- [ ] **Member display:** Ensure Band model deserializes `membersCount` and member `role`; display in BandsScreen
- [ ] **Owner gates:** Update BandsScreen, TrackDetailScreen, SetlistDetailScreen to gate actions on `ownerId == currentUser.id` only
- [ ] **Owner tools:** Add `rotateInviteCode()` and `transferOwnership()` to PublicApi; add dialogs to BandDetailScreen
- [ ] **Cache layer:** Refactor CacheService.get() to check `isOnline` flag; remove staleness (syncedAt) logic
- [ ] **Offline banner:** Add MaterialBanner to RootScaffold conditional on `isOnlineProvider` state
- [ ] **Icons:** Replace placeholder text with Material Icons on Track detail/list, Setlist detail/list
- [ ] **Search picker:** Implement `filteredBandTracksProvider` with debounce via `ref.onDispose()`; replace dialog with ListView; wire `searchQueryProvider` to TextField

---

## Notes for Implementation

### CacheService Refactor Pattern
When refactoring CacheService, the envelope structure `{data, syncedAt}` can remain in Hive storage (for future smart sync in v1.2), but the *logic* changes:
- Stop reading `syncedAt` for staleness decisions
- Start checking `isOnline` flag instead
- Remove all staleness threshold constants (10min, 30min, etc.)

### Riverpod Provider Dependencies
All providers depending on the cache already watch `isOnlineProvider`. Simplify their logic:
- **Before:** `if (cache.syncedAt.difference(now) > 10mins && isOnline) refetch()`
- **After:** `if (isOnline) { fetch and update cache } else { return cached data }`

### Testing Implications
- Remove tests that verify "staleness badge appears at 10 min"; no such logic remains
- Add tests for "offline banner appears when isOnline = false"
- Existing cache population tests remain unchanged (still write {data, syncedAt})

---

## Confidence Assessment

| Area | Level | Rationale |
|------|-------|-----------|
| Stack recommendations | HIGH | All technologies already shipping in v1.0 production app; no new packages needed |
| API integration | HIGH | publicapi.yml schema (fe72e78) fully defined; no ambiguity |
| Cache layer refactor | HIGH | Existing Hive+CacheService proven; refactor is logic simplification, not architectural change |
| Riverpod debounce pattern | HIGH | Pattern documented in official Riverpod docs; already used in v1.0 for disposal cleanup |
| Icon availability | HIGH | Material Design Icons verified in Flutter SDK; all needed icons confirmed present |
| Dependencies | HIGH | No new packages required; no version conflicts expected |

---

## Sources

- [Riverpod Debouncing and Cancellation Documentation](https://riverpod.dev/docs/how_to/cancel)
- [Flutter Material Icons Reference](https://api.flutter.dev/flutter/material/Icons-class.html)
- [Material Symbols Icons 2026 Updates](https://pub.dev/packages/material_symbols_icons/changelog)
- Cadence v1.0 PROJECT.md (current production state: Riverpod 2.6.1, Hive 2.2.3, connectivity_plus 7.3.1)
- Cadence v1.0 pubspec.yaml (validated stack as of 2026-08-20)
