# Phase 9: Homepage Quick Actions - Research

**Researched:** 2026-08-22
**Domain:** Flutter UI feature development (add quick-action buttons and band-picker modal)
**Confidence:** HIGH

## Summary

Phase 9 adds three quick-action buttons to the Homepage (Add Band, Add Song, Add Setlist) with an optional band-picker bottom sheet for the latter two. The implementation reuses existing screens (`CreateBandScreen`, `CreateTrackScreen`, `CreateSetlistScreen`), the existing `bandsListDataProvider` for band data, and proven navigation patterns from `BandsScreen`. No new API endpoints or providers are needed. The design contract is fully locked; the only discretion is widget/icon choices and welcome-card styling details. Risk is minimal: this is purely UI wiring on top of existing, tested infrastructure with straightforward Material Design patterns.

**Primary recommendation:** Structure the changes into two tasks: (1) restructure Home's `_buildContent()` to add the welcome card + quick-actions header + button row, gating Add Song/Setlist with `bandsCount > 0`; (2) add the band-picker bottom-sheet method (either inline or in a small companion file) and wire its selection callback to push `CreateTrackScreen` or `CreateSetlistScreen` with the selected `bandId`.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Welcome text moves into a rounded-rectangle card at the top; layout reserves space for future user avatar
- **D-02:** Three quick actions render as a button row with icon + label (not FAB/bottom-sheet menu)
- **D-03:** Layout applies uniformly to zero-bands and populated states (one layout, not two)
- **D-04:** `BandsScreen`'s FAB + Create/Join menu is untouched — Home's quick actions are an additional entry point
- **D-05:** Band-picker UI is a bottom sheet with `ListTile` per band (band name only, no metadata)
- **D-06:** Picker uses existing `bandsListDataProvider` (no separate fetch, no new provider)
- **D-07:** Picker always shows, even with exactly 1 band (no auto-skip shortcut)
- **D-08:** Dismissing picker without selection closes it cleanly, no error/snackbar
- **D-09:** Add Song/Setlist are disabled (not hidden) when `bandsCount == 0` (plain disabled state)
- **D-10:** All 3 buttons always render; only enabled/disabled state changes
- **D-11:** "Add Band" → direct push to `CreateBandScreen`; "Add Song"/"Add Setlist" → picker → push with selected `bandId`
- **D-12:** No new refresh wiring needed post-create; `homepageDataProvider` already invalidates on Home tab re-entry

### Claude's Discretion
- Exact Material icons for the 3 buttons (recommendations: `Icons.group_add`, `Icons.music_note`, `Icons.playlist_add`)
- Rounded-rectangle welcome-card styling specifics (corner radius, elevation, padding)
- Button widget type (`ElevatedButton.icon`, `OutlinedButton.icon`, `FilledButton.icon`)
- Button row layout on narrow screens (Wrap vs. conditional width vs. Column)
- Band-picker file location (inline in `home_screen.dart` or separate `band_picker_sheet.dart`)

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HOME-01 | User can start "Add band" from Homepage quick action, opening band-creation screen directly | Existing `CreateBandScreen` at `lib/features/bands/create_band_screen.dart`, tested pattern in BandsScreen FAB → CreateBandScreen navigation (line 81-83) |
| HOME-02 | User can start "Add song" or "Add setlist" from Homepage quick actions, picking a band via picker dialog before opening respective create screen | Existing `CreateTrackScreen(required this.bandId)` and `CreateSetlistScreen(required this.bandId)` at `lib/features/tracks/create_track_screen.dart` and `lib/features/setlists/create_setlist_screen.dart`; band data from `bandsListDataProvider` used in BandsScreen |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|-----------|-------------|---|-----------|
| Welcome card rendering | Browser / Client | — | Display-only greeting text; rendered in Home widget |
| Quick-action button taps | Browser / Client | API / Backend | Button presses trigger local navigation to create screens; actual creation is API responsibility |
| Band-picker modal UI | Browser / Client | — | Pure client-side modal; displays cached band list |
| Band selection callback | Browser / Client | — | Local navigation logic; no API call on selection |
| Band data for picker | API / Backend (cached) | Browser / Client | Backend provides `GET /api/band/list`; client caches and reuses via `bandsListDataProvider` |
| Post-create routing | Browser / Client | — | Navigation handled locally; Home re-enters later and gets fresh data via tab-switch invalidation |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | latest stable | UI framework for iOS, Android, web | Project standard; all screens use Flutter/Dart |
| Dart | 3.12.2+ | Programming language | Core Flutter language |
| flutter_riverpod | ^2.6.1 | State management | [VERIFIED: pubspec.yaml:16] All data fetching and navigation state managed via Riverpod |
| http | ^1.6.0 | HTTP client | [VERIFIED: pubspec.yaml:14] API calls; already used by ApiClient |
| flutter_test | built-in | Testing framework | [VERIFIED: pubspec.yaml dev_dependencies:23] Standard Flutter testing; existing test suite uses it |

### Material Design
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Material Design 3 (Flutter built-in) | via Flutter | UI design language | All widgets use Material theme; buttons, bottom sheets, modals are Material standard |
| Material Icons | flutter/material.dart | Icon library | App uses `Icons.group_add`, `Icons.music_note`, etc. (recommended per UI-SPEC) |

### Riverpod State Management
| Pattern | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| riverpod_annotation | ^2.6.1 | Code generation for providers | [VERIFIED: pubspec.yaml:18] Existing providers like `bandsListDataProvider`, `homepageDataProvider` use this |
| flutter_riverpod | ^2.6.1 | Widget integration | [VERIFIED: pubspec.yaml:16] `ConsumerWidget`, `ConsumerStatefulWidget`, `ref.watch()`, `ref.read()` |

### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| connectivity_plus | ^7.3.1 | Offline detection | [VERIFIED: pubspec.yaml:20] Already integrated; `isOnlineProvider` watches this |
| hive | ^2.2.3 | Local storage | [VERIFIED: pubspec.yaml:17] Used by `CacheService` for persistent offline cache |
| hive_flutter | ^1.1.0 | Flutter Hive integration | [VERIFIED: pubspec.yaml:18] Hive adapter for Flutter |

### Installation
```bash
# No new dependencies needed for Phase 9 — reuses existing stack
flutter pub get
```

### Version Verification
All versions are already in `pubspec.yaml` (last verified 2026-08-22). No version bumps required.

## Package Legitimacy Audit

**No new packages introduced this phase.** Phase 9 uses only existing, verified dependencies:

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flutter | pub.dev | 8+ yrs | Official | [flutter/flutter](https://github.com/flutter/flutter) | OK | Approved |
| flutter_riverpod | pub.dev | 4+ yrs | 2.5M+/wk | [rrousselGit/river_pod](https://github.com/rrousselGit/river_pod) | OK | Approved |
| http | pub.dev | 8+ yrs | 3M+/wk | [dart-lang/http](https://github.com/dart-lang/http) | OK | Approved |
| flutter_test | built-in | 8+ yrs | Official | [flutter/flutter](https://github.com/flutter/flutter) | OK | Approved |

**Packages removed due to [SLOP] verdict:** None

**Packages flagged as suspicious [SUS]:** None

---

## Architecture Patterns

### System Architecture Diagram

Phase 9 integrates into the existing Home tab flow:

```
┌─────────────────────────────────────────────────┐
│ HomeScreen (lib/features/home/home_screen.dart) │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │ Watch: homepageDataProvider                │ │
│  │ (online-first cache, Phase 7)              │ │
│  └────────────────────────────────────────────┘ │
│  └─ Fetches: GET /api/homepage                 │
│     Returns: {username, bandsCount}            │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │ _buildContent(data):                       │ │
│  │  • Welcome card (D-01)                     │ │
│  │  • "Quick Actions" header (D-02)           │ │
│  │  • 3 buttons: Add Band / Song / Setlist    │ │
│  │    (enabled/disabled based on bandsCount)  │ │
│  └────────────────────────────────────────────┘ │
│         ↓ button taps                            │
│         ├─ Add Band → Navigator.push(           │
│         │            CreateBandScreen)          │
│         ├─ Add Song → showModalBottomSheet(     │
│         │            band picker)               │
│         └─ Add Setlist → showModalBottomSheet(  │
│                         band picker)            │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │ _showBandPickerSheet():                     │ │
│  │  • Watches: bandsListDataProvider (D-06)   │ │
│  │  • Renders: ListTile per band              │ │
│  │  • On select: Navigator.pop(bandId)        │ │
│  │    then Navigator.push(CreateTrackScreen   │ │
│  │    or CreateSetlistScreen with bandId)     │ │
│  └────────────────────────────────────────────┘ │
│         ↓                                        │
│    CreateTrackScreen / CreateSetlistScreen      │
│    (existing, unchanged)                        │
└─────────────────────────────────────────────────┘
         ↓ after create (navigation)
    TrackDetailScreen / SetlistDetailScreen
         ↓ user re-enters Home tab later
    homepageDataProvider auto-invalidates
    (D-12, Phase 7 tab-switch listener)
    ← Fresh data loaded on re-entry
```

**Data flow:**
1. Home tab loads → `homepageDataProvider` fetches `{username, bandsCount}`
2. User taps quick action → button callback triggers
3. Add Band: direct push to `CreateBandScreen`
4. Add Song / Setlist: picker bottom sheet opens
5. Picker watches `bandsListDataProvider` (already cached/fetched by Bands tab or on-demand)
6. User selects band → sheet closes, selected `bandId` passed to create screen via push
7. After successful create: user lands on detail screen, eventually returns to Home
8. Re-entering Home tab: `selectedTabIndexProvider` listener invalidates `homepageDataProvider` (D-12, existing Phase 7 pattern)
9. Fresh Home data loaded

### Recommended Project Structure

No new directories. Changes are isolated to existing files:

```
lib/features/home/
├── home_screen.dart        ← Modify: restructure _buildContent(), add picker method
└── band_picker_sheet.dart  ← Optional: extract picker if desired (mirrors join_band_dialog.dart pattern)
```

**File organization decision (Claude's discretion):**
- **Option 1 (recommended for Phase 9):** Keep picker as a private `_showBandPickerSheet()` method in `home_screen.dart` — simpler, single-screen ownership, no need for a separate file unless reused later.
- **Option 2:** Extract to `lib/features/home/band_picker_sheet.dart` if anticipating Phase 10 reuse or for module clarity — mirrors existing `join_band_dialog.dart` pattern.

### Pattern 1: Bottom-Sheet Picker for Selection

**What:** Modal bottom sheet displaying a list of items (bands in this case), allowing selection that triggers a callback.

**When to use:** Multi-item selection from a constrained list, where a full-screen navigation would be overkill.

**Example:**
```dart
// Source: lib/features/bands/bands_screen.dart:68-97 (_showCreateJoinMenu)
void _showBandPickerSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final band in bands)
            ListTile(
              leading: const Icon(Icons.group),
              title: Text(band['name'] as String),
              onTap: () {
                Navigator.of(sheetContext).pop();
                // Perform action with selected bandId
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateTrackScreen(bandId: band['id']),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
```

**Key points:**
- `showModalBottomSheet<T>` wraps the builder in a Material-aware sheet
- `SafeArea` ensures content avoids system UI (notches, navigation bars)
- `Column(mainAxisSize: MainAxisSize.min, ...)` makes the sheet size to content, not full-height
- `Navigator.pop()` inside the sheet dismisses it; callback executes outside the sheet context
- `ListTile` provides standard list-item styling (leading icon, title text, onTap handler)

**How this applies to Phase 9:**
- Picker data source: `ref.watch(bandsListDataProvider)`
- ListTile rendering: one per band, name only (no member count per D-05)
- Sheet behavior: tap outside or back button closes without error (D-08)
- Navigation: after pop, push to `CreateTrackScreen(bandId: ...)` or `CreateSetlistScreen(bandId: ...)`

### Pattern 2: Conditional Button Enable/Disable Based on State

**What:** Render a button that is disabled (grayed out, no tap) when a condition is not met.

**When to use:** Guarding actions that require preconditions (e.g., "Add Song" only works if user has at least one band).

**Example:**
```dart
// Source: CONTEXT.md D-09 decision
ElevatedButton.icon(
  onPressed: bandsCount > 0
      ? () => _showBandPickerSheet(context)
      : null,  // null disables the button
  icon: const Icon(Icons.music_note),
  label: const Text('Add Song'),
)
```

**Key points:**
- `onPressed: null` disables the button (Material renders it grayed out)
- No tooltip, snackbar, or additional text needed — disabled visual state communicates the constraint
- This pattern is simple and follows Material Design conventions

### Anti-Patterns to Avoid

- **Don't conditionally hide buttons:** D-10 mandates all 3 buttons always render; only enabled/disabled state changes. Conditional visibility makes the UI less predictable.
- **Don't fetch band list separately in picker:** D-06 requires reusing `bandsListDataProvider`. A separate picker-specific fetch would duplicate network calls and cache logic.
- **Don't auto-skip picker for single band:** D-07 mandates the picker always shows. Shortcuts like "if 1 band, go directly to create" violate the consistent UX contract.
- **Don't show error on picker dismiss:** D-08 specifies that tapping outside the sheet just closes it. No snackbar or error dialog needed.
- **Don't gate welcome card visibility on band count:** The welcome card should always render (it's not conditional). Only the button row state changes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Styling a rounded-rectangle card with padding | A custom painted shape or manual border setup | `Card` or `Container` with `decoration: BoxDecoration(borderRadius: ...)` | Material handles elevation, shadow, color inheritance, dark mode automatically |
| Detecting which button the user tapped | Manual state tracking (`_selectedButton`) | Callback directly in `onPressed:` | Simpler, no state churn, follows Material convention |
| Displaying a selectable list of items | A custom scrollable Column with tap handlers | `ListTile` widgets inside `showModalBottomSheet` | ListTile handles leading icon, text styling, dividers, tap feedback automatically |
| Managing enabled/disabled button appearance | Manual opacity/color changes | Material's `onPressed: null` pattern | Material's disabled state handles color, cursor, feedback consistently |
| Selecting an item from a bottom sheet | Custom Navigator logic or global state | `showModalBottomSheet<T>(... Navigator.pop<T>(value) ...)` pattern | Flutter's modal API handles dismiss, back-button, outside-tap all correctly |

**Key insight:** Flutter's Material Design widgets and the Navigator API abstract away most of the complexity in this phase. Custom solutions would add maintenance burden and likely miss edge cases (dark mode, accessibility, platform conventions).

---

## Common Pitfalls

### Pitfall 1: Picker Shows Even When Disabled

**What goes wrong:** Developer adds a picker method but forgets to gate the button's `onPressed` callback with `bandsCount > 0`, so the picker can be opened even when `Add Song` / `Add Setlist` are disabled.

**Why it happens:** The button disable state is a visual-only guard; the underlying `onPressed` callback is not automatically gated.

**How to avoid:** Always check `bandsCount > 0` in the `onPressed` callback:
```dart
onPressed: bandsCount > 0
    ? () => _showBandPickerSheet(context, shouldCreateTrack: true)
    : null,
```

**Warning signs:** During testing, tapping a disabled button unexpectedly opens the picker, or the picker crashes because no bands exist.

### Pitfall 2: Picker Fetches Its Own Band List

**What goes wrong:** Developer adds a separate provider or API call in the picker to fetch `GET /api/band/list`, duplicating the `bandsListDataProvider` fetch logic.

**Why it happens:** Oversight — forgetting that `bandsListDataProvider` already exists and is watched by BandsScreen and other places.

**How to avoid:** Reuse `bandsListDataProvider` in the picker (D-06):
```dart
final bandsAsync = ref.watch(bandsListDataProvider);
// Then in the sheet builder, render from bandsAsync.value
```

**Warning signs:** Two overlapping network calls for band list; cache invalidation gets complicated; picker doesn't respect offline state.

### Pitfall 3: Picker Skips to Create Screen for Single Band

**What goes wrong:** Developer optimizes for the single-band case: "if user has 1 band, skip the picker and go straight to CreateTrackScreen."

**Why it happens:** Seems like a UX shortcut, but it violates D-07.

**How to avoid:** Always show the picker, regardless of band count (D-07):
```dart
// Always show picker, even if bandsCount == 1
void _showBandPickerSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final bandsAsync = ref.watch(bandsListDataProvider);
      return bandsAsync.when(
        data: (bands) => _buildBandPickerContent(sheetContext, bands),
        // ... loading/error states
      );
    },
  );
}
```

**Warning signs:** Phase 9 test or acceptance check finds that single-band picker is skipped.

### Pitfall 4: Welcome Card Doesn't Reserve Avatar Space

**What goes wrong:** Welcome text fills the entire card, leaving no room for a future user avatar widget (noted in D-01).

**Why it happens:** Developer doesn't layout the card with avatar space in mind.

**How to avoid:** Use a `Row` with the avatar placeholder on one side and the text on the other:
```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Row(
      children: [
        // Avatar placeholder (can be Icon or Image later)
        Container(width: 48, height: 48, color: Colors.grey),
        const SizedBox(width: 16),
        // Text, wrapped in Expanded to prevent overflow
        Expanded(
          child: Text(
            'Welcome, $username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  ),
)
```

**Warning signs:** Avatar image can't fit in the welcome card; card looks cramped if avatar is added later.

### Pitfall 5: Button Row Overflows on Mobile

**What goes wrong:** Three buttons in a fixed-width `Row` overflow on narrow phone screens.

**Why it happens:** `Row` doesn't wrap; executor didn't test on a small viewport.

**How to avoid:** Use `Wrap` or conditional layout:
```dart
// Option A: Wrap automatically wraps buttons to next line if needed
Wrap(
  spacing: 16,   // gap between buttons in a row
  runSpacing: 8, // gap between rows
  children: [
    ElevatedButton.icon(...), // Add Band
    ElevatedButton.icon(...), // Add Song
    ElevatedButton.icon(...), // Add Setlist
  ],
)

// Option B: Conditional layout based on available width
```

**Warning signs:** Buttons overflow in the layout debugger; text truncates or buttons become untappable.

### Pitfall 6: Picker Doesn't Handle Loading/Error in Bands Data

**What goes wrong:** Picker renders a blank sheet if `bandsListDataProvider` is still loading or has errored.

**Why it happens:** Forgot to handle `AsyncValue` states (loading/error/data).

**How to avoid:** Use `bandsAsync.when()` in the picker:
```dart
showModalBottomSheet<void>(
  context: context,
  builder: (sheetContext) {
    final bandsAsync = ref.watch(bandsListDataProvider);
    return bandsAsync.when(
      data: (bands) => _buildPickerContent(sheetContext, bands),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading bands')),
    );
  },
);
```

**Warning signs:** Picker opens but shows blank or crashes when bands data is still loading.

---

## Runtime State Inventory

**Trigger:** This is a feature-add phase, not a rename/refactor/migration.

**Action:** SKIPPED — no stored data, live service config, OS-registered state, secrets, or build artifacts need updating. Phase 9 adds UI only; no persistence changes.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### Quick-Action Button Row

```dart
// Source: 09-UI-SPEC.md Component Spec 3 + BandsScreen:68-97 pattern
Wrap(
  spacing: 16,   // md token: gap between buttons
  runSpacing: 8, // sm token: gap between rows on wrap
  children: [
    ElevatedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateBandScreen()),
      ),
      icon: const Icon(Icons.group_add),
      label: const Text('Add Band'),
    ),
    ElevatedButton.icon(
      onPressed: bandsCount > 0
          ? () => _showBandPickerSheet(context, shouldCreateTrack: true)
          : null,
      icon: const Icon(Icons.music_note),
      label: const Text('Add Song'),
    ),
    ElevatedButton.icon(
      onPressed: bandsCount > 0
          ? () => _showBandPickerSheet(context, shouldCreateTrack: false)
          : null,
      icon: const Icon(Icons.playlist_add),
      label: const Text('Add Setlist'),
    ),
  ],
)
```

### Welcome Card

```dart
// Source: 09-UI-SPEC.md Component Spec 1 + existing home_screen.dart pattern
Card(
  color: Theme.of(context).colorScheme.surfaceContainerLow,
  elevation: 1,
  child: Padding(
    padding: const EdgeInsets.all(24), // lg token
    child: Row(
      children: [
        // Avatar placeholder reserved for future use (D-01)
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withOpacity(0.3),
          ),
        ),
        const SizedBox(width: 16), // md token gap
        Expanded(
          child: Text(
            'Welcome, $username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ],
    ),
  ),
)
```

### Band-Picker Bottom Sheet

```dart
// Source: BandsScreen:68-97 _showCreateJoinMenu pattern + 09-UI-SPEC.md Component Spec 4
void _showBandPickerSheet(
  BuildContext context,
  WidgetRef ref,
  bool shouldCreateTrack,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final bandsAsync = ref.watch(bandsListDataProvider);
      return SafeArea(
        child: bandsAsync.when(
          data: (bands) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final band in bands)
                ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(
                    band['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    final bandId = band['id'] as String;
                    if (shouldCreateTrack) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateTrackScreen(bandId: bandId),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateSetlistScreen(bandId: bandId),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading bands'),
          ),
        ),
      );
    },
  );
}
```

### Integration in _buildContent()

```dart
// Source: existing home_screen.dart + Phase 9 changes
Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
  final username = data['username'] as String;
  final bandsCount = data['bandsCount'] as int;

  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16), // md token
      child: Column(
        children: [
          // D-01: Welcome card with rounded corners and padding
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // 12dp radius
            ),
            child: Padding(
              padding: const EdgeInsets.all(24), // lg token
              child: Text(
                'Welcome, $username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 24), // lg token gap
          // D-02: Section header
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16), // md token gap
          // D-10: Always render all 3 buttons; only enabled/disabled changes
          Wrap(
            spacing: 16,   // md token
            runSpacing: 8, // sm token
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateBandScreen()),
                ),
                icon: const Icon(Icons.group_add),
                label: const Text('Add Band'),
              ),
              ElevatedButton.icon(
                onPressed: bandsCount > 0
                    ? () => _showBandPickerSheet(context, ref, true)
                    : null,
                icon: const Icon(Icons.music_note),
                label: const Text('Add Song'),
              ),
              ElevatedButton.icon(
                onPressed: bandsCount > 0
                    ? () => _showBandPickerSheet(context, ref, false)
                    : null,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add Setlist'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

---

## Environment Availability

**Dependency audit:**

| Dependency | Required By | Available | Version | Fallback |
|-----------|-----------|-----------|---------|----------|
| Flutter SDK | All builds | ✓ | latest stable | — |
| Dart 3.12.2+ | All builds | ✓ | 3.12.2+ | — |
| Android SDK | Android build | ✓ | API 21+ | — |
| Xcode | iOS build | ✓ (on macOS) | 14+ | — |
| `flutter test` | Test execution | ✓ | built-in | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

All required tools are present. Builds and tests can execute immediately.

---

## Validation Architecture

**Config:** `workflow.nyquist_validation: true` in `.planning/config.json`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) + MockClient from http/testing.dart |
| Config file | None — standard Flutter project |
| Quick run command | `flutter test test/features/home/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HOME-01 | Tapping "Add band" navigates to CreateBandScreen | Widget | `flutter test test/features/home/home_screen_test.dart::testAddBandNavigation` | ❌ Wave 0 |
| HOME-02 (part 1) | Tapping "Add song" opens band-picker bottom sheet | Widget | `flutter test test/features/home/home_screen_test.dart::testAddSongOpensPickerWhenBandsExist` | ❌ Wave 0 |
| HOME-02 (part 2) | Selecting band from picker navigates to CreateTrackScreen with correct bandId | Widget | `flutter test test/features/home/home_screen_test.dart::testPickerNavigatesToCreateTrackScreen` | ❌ Wave 0 |
| HOME-02 (part 3) | Tapping "Add setlist" opens band-picker bottom sheet | Widget | `flutter test test/features/home/home_screen_test.dart::testAddSetlistOpensPickerWhenBandsExist` | ❌ Wave 0 |
| HOME-02 (part 4) | Selecting band from picker navigates to CreateSetlistScreen with correct bandId | Widget | `flutter test test/features/home/home_screen_test.dart::testPickerNavigatesToCreateSetlistScreen` | ❌ Wave 0 |
| HOME-01/02 | Add song / setlist buttons are disabled when bandsCount == 0 | Widget | `flutter test test/features/home/home_screen_test.dart::testAddSongSetlistDisabledWhenNoBands` | ❌ Wave 0 |
| HOME-01/02 | Add song / setlist buttons are enabled when bandsCount > 0 | Widget | `flutter test test/features/home/home_screen_test.dart::testAddSongSetlistEnabledWhenBandsExist` | ❌ Wave 0 |
| HOME-02 | Dismissing picker without selection closes it and stays on Home | Widget | `flutter test test/features/home/home_screen_test.dart::testDismissPickerStaysOnHome` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/features/home/home_screen_test.dart` — tests HOME-01/HOME-02 behaviors
- **Per wave merge:** `flutter test` — full suite including provider tests and regression tests
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/features/home/home_screen_test.dart` — widget tests covering all 8 behaviors above (navigation, picker open/close, enabled/disabled states)
- [ ] Fixtures/mocks: `MockHomeDataProvider`, `MockBandsProvider` to simulate various states (zero bands, multiple bands, loading, error)
- [ ] Test harness: integration with existing test patterns from `test/providers/homepage_provider_test.dart` (ProviderContainer + MockClient)

**Recommended test coverage structure:**
```dart
// test/features/home/home_screen_test.dart
void main() {
  group('HomeScreen quick actions (Phase 9)', () {
    testWidgets('Add band button navigates to CreateBandScreen', (tester) async { ... });
    testWidgets('Add song button opens band-picker when bandsCount > 0', (tester) async { ... });
    testWidgets('Add song button is disabled when bandsCount == 0', (tester) async { ... });
    testWidgets('Band picker selection navigates to CreateTrackScreen', (tester) async { ... });
    testWidgets('Dismissing picker stays on Home', (tester) async { ... });
    // Similar for Add setlist
  });
}
```

**Framework install:** Already present (flutter_test, flutter, pubspec.yaml dependencies). No additional installation needed.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | Auth token already handled by ApiClient; Phase 9 adds no new auth flows |
| V3 Session Management | no | Session already managed by ApiClient/AuthSession; no changes |
| V4 Access Control | yes | Navigation guards (phase 9 disables buttons when preconditions aren't met, e.g., bandsCount == 0) are UI-only. Backend API already enforces who can create tracks/setlists in which bands. Phase 9 does not add new authorization logic. |
| V5 Input Validation | no | No user input (band creation is delegated to CreateBandScreen, track/setlist creation to their screens). Picker selection only passes band ID, which is non-sensitive data from existing provider. |
| V6 Cryptography | no | No encryption or cryptographic operations added this phase |
| V7 Error Handling | yes | Picker handles loading/error states of `bandsListDataProvider` (existing safe patterns). No new error exposure. |
| V8 Data Protection | no | No sensitive data stored or transmitted differently than existing screens |

### Known Threat Patterns for Flutter + Riverpod + Material

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Deep link to CreateTrackScreen without valid bandId | Spoofing (invalid band access) | Existing CreateTrackScreen requires `required String bandId`, passed only after picker selection from authenticated band list. Backend CREATE /band/{bandId}/track endpoint validates ownership. Phase 9 adds no new deep-link vulnerability. |
| Picker displays sensitive band metadata (member emails, roles) | Information Disclosure | D-05 mandates picker shows band name only (no metadata). Existing `bandsListDataProvider` returns full band objects; picker intentionally filters to name only. No new leakage. |
| Offline picker shows stale band list | Information Disclosure (outdated) | Phase 7 cache model and global offline banner already handle this. Picker follows same cache-serving behavior. No new exposure. |

**Sensitive data in this phase:**
- `bandId` (non-sensitive: public identifier, user already sees their bands in BandsScreen)
- `username` (non-sensitive: already displayed on Home)
- Band names (non-sensitive: user's own bands)

**No new API keys, secrets, or protected routes introduced this phase.**

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Home screen showed only band count (pre-Phase 9) | Welcome card + quick-action buttons (Phase 9) | 2026-08-22 | Users can jump directly to create flows from Home; reduces navigation depth |
| Navigation to Create flows required manual band selection via BandsScreen (pre-Phase 9) | Quick-action buttons + optional band-picker on Home (Phase 9) | 2026-08-22 | Faster path to common workflows (add song/setlist) |
| All users had to navigate to Bands tab to create anything (pre-Phase 9) | Add Band available from Home; Add Song/Setlist via picker (Phase 9) | 2026-08-22 | Improves discoverability and reduces friction |

**Deprecated/outdated:**
- Home's zero-bands-only "No bands yet... Create Band" block is replaced by consistent quick-actions layout (D-03)
- BandsScreen's FAB is NOT deprecated; remains the independent create/join entry point (D-04)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | `CreateTrackScreen` and `CreateSetlistScreen` require a `bandId` parameter | Standard Stack → Code Examples | High — if they don't, the navigation callback will crash when attempting to pass bandId |
| A2 | `bandsListDataProvider` returns a `List<Map<String, dynamic>>` with at least an 'id' and 'name' field per band | Standard Stack → Common Pitfalls | High — if the structure differs, ListTile rendering will fail or show wrong data |
| A3 | `homepageDataProvider` returns a `Map<String, dynamic>` with 'username' and 'bandsCount' fields | Architecture → Data Flow | High — if the schema differs, welcome card and button state logic will fail |
| A4 | Material's `showModalBottomSheet` API and dismiss behavior (tap outside, back button) work as documented | Architecture → Patterns | Medium — unlikely, but dismissal behavior should be tested; unlikely to differ from Material spec |
| A5 | Existing `NavigatorObserver` or navigation logic does not conflict with multiple `Navigator.push` calls from picker callback | Architecture → Navigation | Low — Phase 9 follows the same navigation pattern as existing BandsScreen; unlikely to conflict |

**If this table is empty:** N/A — all major claims were verified against the codebase or existing patterns.

---

## Open Questions

1. **Avatar Widget Detail**
   - What we know: D-01 mandates welcome card reserves space for future avatar widget
   - What's unclear: Should the avatar placeholder be a hardcoded empty Container, or a stub Avatar widget for easier future replacement?
   - Recommendation: Use a simple `Container` with gray background; no custom Avatar widget needed until avatar feature is scoped

2. **Button Row Overflow on Narrow Screens**
   - What we know: Buttons must render on all screen widths; D-02/Claude's discretion allows layout flexibility
   - What's unclear: Should buttons always stay in one row (with text truncation), or wrap/stack on mobile?
   - Recommendation: Use `Wrap` widget (auto-wraps if needed); recommended in UI-SPEC

3. **Picker Icon Consistency**
   - What we know: UI-SPEC recommends `Icons.group` for band picker list items
   - What's unclear: Should picker use same icon as "Add Band" button (`Icons.group_add`) or a different icon?
   - Recommendation: Use `Icons.group` (simpler icon for list context; `Icons.group_add` emphasizes "add action" which is not what picker does)

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: codebase] `lib/features/home/home_screen.dart` (1-154) — current Home screen implementation, providers, error handling patterns
- [VERIFIED: codebase] `lib/features/bands/bands_screen.dart` (1-97) — band picker template (`_showCreateJoinMenu`), navigation patterns, ListTile rendering
- [VERIFIED: codebase] `lib/features/bands/create_band_screen.dart` (1-50) — CreateBandScreen constructor and navigation
- [VERIFIED: codebase] `lib/features/tracks/create_track_screen.dart` (10-15) — CreateTrackScreen signature with `required String bandId`
- [VERIFIED: codebase] `lib/features/setlists/create_setlist_screen.dart` (11-14) — CreateSetlistScreen signature with `required String bandId`
- [VERIFIED: codebase] `lib/providers/bands_provider.dart` (1-50) — bandsListDataProvider online-first cache model
- [VERIFIED: codebase] `lib/providers/homepage_provider.dart` (1-107) — homepageDataProvider shape and refresh pattern
- [VERIFIED: codebase] `lib/navigation/root_scaffold.dart` (1-73) — tab structure and navigation provider
- [VERIFIED: codebase] `pubspec.yaml` (1-67) — dependency versions (flutter_riverpod, flutter_test, http)
- [VERIFIED: codebase] `test/providers/homepage_provider_test.dart` (1-256) — test patterns, ProviderContainer setup, MockClient usage
- [CITED: .planning/phases/09-homepage-quick-actions/09-CONTEXT.md] — all locked design decisions (D-01 through D-12)
- [CITED: .planning/phases/09-homepage-quick-actions/09-UI-SPEC.md] — component specifications, spacing scale, typography, copywriting contract

### Secondary (MEDIUM confidence)
- [CITED: .planning/REQUIREMENTS.md] — HOME-01, HOME-02 requirement definitions
- [CITED: .planning/STATE.md] — project roadmap and phase dependencies
- [ASSUMED: Flutter Material Design docs] — showModalBottomSheet API, ListTile behavior, button enable/disable patterns (not re-verified this session, but widely used in codebase)

### Tertiary (LOW confidence)
- None — all material findings are grounded in primary sources or verified patterns

---

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH — all dependencies are in pubspec.yaml (verified); patterns used throughout existing code
- **Architecture:** HIGH — Phase 9 integrates cleanly into existing navigation + provider patterns; no architectural constraints
- **Data flow:** HIGH — homepageDataProvider and bandsListDataProvider are tested and stable
- **Pitfalls:** HIGH — identified based on existing codebase patterns and design decision review
- **Testing:** MEDIUM — test framework is standard (flutter_test), but specific Phase 9 tests don't exist yet (Wave 0 gap)
- **Security:** HIGH — no new security-sensitive operations; follows existing ApiClient/navigation guards

**Research date:** 2026-08-22
**Valid until:** 2026-08-29 (low-churn feature; decisions are locked; validity extends 7 days for design-heavy phases)

---

*Phase: 9 — Homepage Quick Actions*
*Research completed: 2026-08-22*
*Ready for planning.*
