# Phase 8: Band Owner Tools - Research

**Researched:** 2026-08-21
**Domain:** Flutter band management UI and API integration
**Confidence:** HIGH

## Summary

Phase 8 adds two owner-gated mutations to the existing Band Detail screen: invite code rotation and ownership transfer. Both are small, additive features that reuse established patterns (`ConfirmRemoveMemberDialog` template, `BandDetailData.updateName()` and `BandsListData.renameBand()` local-patch patterns, Riverpod's `invalidate()` and direct state updates). The API contract is complete and in place (both endpoints already defined in `publicapi.yml`). No new navigation surfaces, no schema migrations, no external dependencies. All work is UI + two new `PublicApi` methods + two new `BandDetailData`/`BandsListData` mutation helpers.

**Primary recommendation:** Implement in a single plan: create two new dialog files, add PopupMenuButton to member list + Copy/Rotate icons to invite-code row, add two `PublicApi` methods, add two `BandDetailData`/`BandsListData` patch methods, wire them into the dialogs. All changes are scoped to `lib/features/bands/` and `lib/providers/bands_provider.dart`.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01 through D-12 (CONTEXT.md)** establish the implementation contract:

- **D-01/D-02:** "Make owner" action is a per-row menu item (PopupMenuButton) in the member-list trailing slot, replacing the current standalone `person_remove` IconButton. Menu holds both "Make owner" and "Remove" items.
- **D-03:** Remove action keeps existing behavior; only its entry point moves into the PopupMenuButton.
- **D-04:** Transfer confirmation dialog must explicitly state self-effect: "You will no longer be the owner of [band]."
- **D-05:** Dialog error/loading handling matches `ConfirmRemoveMemberDialog` exactly: spinner, inline error, "Requires connection" offline gate, dialog stays open on error.
- **D-06/D-07:** Rotate confirmation dialog first; then Invite Code row becomes `[code] [Copy icon] [Rotate icon]` (both IconButtons, not TextButton).
- **D-08:** On successful rotate, patch `inviteCode` in-place via `BandDetailData.updateName()`'s pattern; show snackbar immediately without refetch.
- **D-09:** On successful transfer, invalidate `bandDetailDataProvider(bandId)` and refetch (no response body to trust for optimistic patch).
- **D-10:** Also patch `bandsListDataProvider` entry after transfer (update `ownerId` for the list-side badge), using known target `userId`.
- **D-11:** Rotate does NOT need list-side patch (BandListItem schema has no `inviteCode` field).
- **D-12:** Both actions stay in-place on `band_detail_screen`; no navigation away.

### Claude's Discretion

- Material icon choice for "Make owner" (`Icons.workspace_premium` suggested) and Rotate's circular-arrow (`Icons.refresh` / `Icons.autorenew`).
- PopupMenuButton internal styling (dividers, text labels, icon styling).
- Whether `BandDetailData._version` guard needs bumping in the new patch methods — pattern already established in Phase 2/6/7; executor's call on exact wiring.

### Deferred Ideas

None — phase scope is fixed. Homepage quick actions and searchable setlist track picker are Phases 9–10.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BAND-11 | Band owner can rotate the band's invite code | API endpoint exists (POST `/api/band/{bandId}/rotate-invite-code`, returns `RotateBandInviteCodeResponseBody.newInviteCode`); UI pattern mirrors `BandDetailScreen.updateName()`; local-patch pattern established in `BandDetailData.updateName()` |
| BAND-12 | Band owner can transfer ownership to another member | API endpoint exists (POST `/api/band/{bandId}/transfer-ownership`, body `{userId}`, 200 no content); refetch pattern via `invalidate()` established; list-patch pattern via `renameBand()` established |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | Latest stable | UI framework for iOS/Android | Project baseline; all UI work uses Flutter |
| Dart | 3.12.2+ | Core language | Via Flutter SDK |
| Riverpod | Already in use | State management & provider pattern | Established Phase 1; data fetching, invalidation, local patches |
| Material 3 | ColorScheme.fromSeed (green seed) | Design system | Existing theme applied project-wide |
| flutter_secure_storage | 11.0.0 | Token persistence | Already in auth layer; not used for this phase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Material Icons | Built-in | Icon assets | All UI icon rendering (crown-like for "Make owner", circular-arrow for Rotate, person_remove for Remove) |
| AlertDialog | Built-in Flutter | Modal confirmation | ConfirmTransferOwnershipDialog, ConfirmRotateInviteCodeDialog (mirrors ConfirmRemoveMemberDialog) |
| PopupMenuButton | Built-in Flutter | Per-row action menu | Member-list trailing slot for "Make owner" + "Remove" items |

**Installation:** No new packages required. All are project-wide dependencies already in `pubspec.yaml`.

**Version verification:** [VERIFIED: Flutter SDK] — project uses latest stable; `pubspec.lock` confirms flutter_lints 6.0.0, http 1.6.0, flutter_secure_storage 11.0.0 are current.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Invite code rotation | API / Backend | Frontend (UI) | Backend generates new code; frontend validates owner-gating, submits request, optimistically patches display |
| Ownership transfer | API / Backend | Frontend (UI) | Backend validates owner status and target user membership; frontend validates owner-gating, submits request, refetches detail to confirm |
| Owner-gated UI visibility | Frontend (UI) | — | Determined by comparing `profileDataProvider` user ID with `BandDetailData.ownerId`; tristate ownership check ensures controls stay hidden until profile loads |
| Dialog error handling | Frontend (UI) | — | UI layer catches ApiException, displays inline in dialog, keeps dialog open for retry |

---

## Architecture Patterns

### System Architecture Diagram

```
User on BandDetailScreen
    ↓
[Owner checks via ownershipStatus(profileAsync, ownerId)]
    ├─ null (profile loading) → controls hidden
    ├─ false (non-owner) → controls hidden
    └─ true (owner) → controls visible
         ↓
[Member row PopupMenuButton] ──→ "Make owner" tap
    ↓
ConfirmTransferOwnershipDialog
    ├─ User confirms → _transfer() called
    │    ├─ POST /api/band/{bandId}/transfer-ownership {userId}
    │    ├─ On success:
    │    │   ├─ ref.invalidate(bandDetailDataProvider(bandId))
    │    │   ├─ ref.read(bandsListDataProvider).patchBandOwner(...)
    │    │   ├─ Navigator.pop() + snackbar
    │    │   └─ Detail screen refetches, re-renders with new owner
    │    └─ On error: _errorMessage displayed, dialog stays open
    └─ User cancels → dialog closes

[Invite Code row] ──→ Rotate icon tap (owner-only)
    ↓
ConfirmRotateInviteCodeDialog
    ├─ User confirms → _rotate() called
    │    ├─ POST /api/band/{bandId}/rotate-invite-code
    │    ├─ On success:
    │    │   ├─ Extract newInviteCode from response
    │    │   ├─ BandDetailData.rotateInviteCode(newInviteCode)
    │    │   ├─ Patch inviteCode in-place (no refetch)
    │    │   ├─ Navigator.pop() + snackbar
    │    │   └─ Row re-renders with new code immediately
    │    └─ On error: _errorMessage displayed, dialog stays open
    └─ User cancels → dialog closes
```

### Recommended Project Structure

```
lib/features/bands/
├── band_detail_screen.dart          [MODIFIED] — add PopupMenuButton, Copy/Rotate icons
├── confirm_remove_member_dialog.dart [EXISTING] — template for new dialogs
├── confirm_transfer_ownership_dialog.dart  [NEW] — ownership transfer confirmation
├── confirm_rotate_invite_code_dialog.dart  [NEW] — invite code rotation confirmation
└── band_avatar.dart                 [UNCHANGED]

lib/providers/
├── bands_provider.dart              [MODIFIED] — add patchBandOwner(), rotateInviteCode() methods
└── connectivity_provider.dart       [UNCHANGED]

lib/api/
├── public_api.dart                  [MODIFIED] — add rotateInviteCode(), transferOwnership() methods
├── api_client.dart                  [UNCHANGED]
└── api_exception.dart               [UNCHANGED]
```

### Pattern 1: Confirmation Dialog with Loading & Error State

**What:** A modal AlertDialog that submits a mutation, displays loading spinner and inline errors, stays open on failure, and pops on success.

**When to use:** Any user-initiated destructive or irreversible action (member removal, ownership transfer, invite code rotation, band deletion).

**Example:**
```dart
// Template: ConfirmRemoveMemberDialog (109 lines)
// Located at: lib/features/bands/confirm_remove_member_dialog.dart (VERIFIED: lib/features/bands/confirm_remove_member_dialog.dart:1-109)

class _ConfirmRemoveMemberDialogState extends ConsumerState<...> {
  bool _isSubmitting = false;       // Loading state
  String? _errorMessage;            // Error display

  Future<void> _remove() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // API call — wraps any response in Future<void>
      await ref.read(publicApiProvider).removeMember(...);
      // Post-success: invalidate/patch state
      ref.invalidate(bandDetailDataProvider(widget.bandId));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      // ApiException carries message; display inline
      setState(() => _errorMessage = e.message);
    } catch (_) {
      // Fallback for unexpected errors
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return AlertDialog(
      title: Text('Remove ${widget.memberUsername}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description...'),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Tooltip(
          message: isOnline ? '' : 'Requires connection',
          child: FilledButton(
            onPressed: (!isOnline || _isSubmitting) ? null : _remove,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Action'),
          ),
        ),
      ],
    );
  }
}
```

**Source:** [VERIFIED: lib/features/bands/confirm_remove_member_dialog.dart:13-109] — This dialog implements the exact state management pattern (ConsumerStatefulWidget, _isSubmitting, _errorMessage, ApiException catch, offline gating via FilledButton disabled state + Tooltip, dialog stays open on error). Both new dialogs (ConfirmTransferOwnershipDialog, ConfirmRotateInviteCodeDialog) replicate this shape verbatim, differing only in title/body text and the specific API method called.

### Pattern 2: Local State Patch After Mutation (No Response Body)

**What:** When an API endpoint returns `200` with no response body schema, the client merges known values into the cached state instead of refetching (or refetches if no trusted value exists to merge).

**When to use:** Mutations that return empty responses (e.g., `UpdateBand`, `TransferBandOwnership`) where you have enough context (user-supplied new value, or the target user ID) to update local cache without the server's echoed response.

**Example (Rotate):**
```dart
// Pattern: BandDetailData.updateName() (VERIFIED: lib/providers/bands_provider.dart:247-255)
// Mirrors same pattern for invite code rotation

Future<void> rotateInviteCode(String newInviteCode) async {
  final current = state.valueOrNull;
  if (current == null) return;
  final updated = {...current, 'inviteCode': newInviteCode};
  _version++;
  state = AsyncData(updated);
  await ref.read(cacheServiceProvider).writeBandDetail(bandId, updated);
  ref.read(bandDetailSyncedAtProvider(bandId).notifier).set(DateTime.now());
}
```

**Source:** [VERIFIED: lib/providers/bands_provider.dart:141-152] — `BandsListData.renameBand()` and [VERIFIED: lib/providers/bands_provider.dart:247-255] — `BandDetailData.updateName()` both follow the `{spread, merge new field, _version++, AsyncData, cache write, syncedAt bump}` pattern that rotate will copy.

### Pattern 3: List-Side Patch After Detail-Side Mutation (D-10)

**What:** After a detail-screen mutation affects a list-side badge/state, patch the list provider's corresponding entry so IndexedStack-kept screens (e.g., BandsScreen) reflect the change immediately without a refetch.

**When to use:** When a detail-screen change affects the list view and that list view is kept alive in an IndexedStack (not disposed/recreated on tab-switch), an optimistic local patch prevents stale badges.

**Example (Transfer Ownership):**
```dart
// Pattern template: BandsListData.renameBand() (VERIFIED: lib/providers/bands_provider.dart:141-152)
// Transfer ownership will call a similar patchBandOwner() method:

void patchBandOwner(String bandId, String newOwnerId) {
  final current = state.valueOrNull;
  if (current == null) return;
  final updated = [
    for (final band in current)
      if (band['id'] == bandId) {...band, 'ownerId': newOwnerId} else band,
  ];
  _version++;
  state = AsyncData(updated);
  unawaited(ref.read(cacheServiceProvider).writeBands(updated));
  ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
}
```

**Source:** [VERIFIED: lib/providers/bands_provider.dart:141-152] — Exact shape reused; the patch logic (`for (final band in current) if (band['id'] == bandId) {...band, 'field': newValue}`), the `_version++`, AsyncData, cache write, and syncedAt bump are all copied from `renameBand()`.

### Pattern 4: Member-List Row with Owner-Gated Menu

**What:** A ListTile with trailing PopupMenuButton containing owner-only actions ("Make owner", "Remove"), visible only when the viewer is the owner and the target row is not the owner's own row.

**When to use:** Any table/list displaying team members where the viewer might be able to promote, demote, or remove members (owner-gated operations).

**Example:**
```dart
// Source: BandDetailScreen (VERIFIED: lib/features/bands/band_detail_screen.dart:145-180)
// Phase 8 D-01/D-02 modifies trailing from a single IconButton to PopupMenuButton:

final showMenu = isOwner == true && memberUserId != ownerId;

return ListTile(
  title: Text(memberUsername),
  trailing: showMenu
      ? Tooltip(
          message: isOnline ? '' : 'Requires connection',
          child: PopupMenuButton<int>(
            enabled: isOnline,
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium),  // or crown-like icon
                    const SizedBox(width: 8),
                    const Text('Make owner'),
                  ],
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => ConfirmTransferOwnershipDialog(...),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_remove, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Text('Remove', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => ConfirmRemoveMemberDialog(...),
                ),
              ),
            ],
          ),
        )
      : null,
);
```

**Source:** [VERIFIED: lib/features/bands/band_detail_screen.dart:145-180] — Current member list rendering; Phase 8 replaces the trailing `IconButton` (line 160–177 today) with PopupMenuButton.

### Anti-Patterns to Avoid

- **Optimistic client-side `ownerId` patch for transfer:** D-09 explicitly rejects this. Because `TransferBandOwnership` returns `200` with no body, the planner might assume "we know the target userId, so patch client-side." That's wrong — the server might reject the transfer (e.g., target user isn't a member anymore, or band membership changed server-side). Always invalidate and refetch when the server returns no response body to trust.
- **Forget list-side patch:** If the detail-screen refetch completes before the planner remembers to patch `bandsListDataProvider`, the Bands tab (kept alive in IndexedStack) will show a stale "Owner" badge. D-10 is explicit: **always** patch the list entry after a successful detail-side transfer. (Rotate doesn't have this issue per D-11 — inviteCode isn't in BandListItem schema.)
- **Render owner-controls before profile loads:** The `ownershipStatus()` tri-state ensures controls stay hidden (null) until the profile is loaded. Never render-then-hide-on-load — that's a UX flicker and a security risk.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dialog state + loading + error display | Custom StatefulWidget managing setState/error UI | `ConfirmRemoveMemberDialog` template | Riverpod integration, ApiException catch pattern, offline gating, spinner rendering, error text styling all battle-tested across Phase 2–6 band mutations |
| Owner-only action visibility | Manual if-checks scattered in build() | `ownershipStatus()` tri-state helper + `isOwner == true` gate | Single source of truth for ownership check; prevents profile-not-loaded bugs; matches existing pattern |
| Local state patch after mutation | Manual state assignment + cache write | `BandDetailData.updateName()` / `BandsListData.renameBand()` pattern | `_version` guard prevents race conditions; `syncedAt` bump coordinates with cache invalidation; both already proven in Phase 6 renames |
| Copy-to-clipboard for invite code | Custom Clipboard wrapper | `Clipboard.setData(ClipboardData(text: ...))` | Built-in Flutter API; no failure path on Android/iOS; already used elsewhere in project |
| Circular-arrow icon for Rotate | Custom SVG / canvas drawing | `Icons.refresh` or `Icons.autorenew` from Material Icons | Project-wide Material Icons; no dependency bloat; consistent with existing UI |

**Key insight:** Confirm dialogs and local-patch mutations are the highest-risk areas in this phase because they touch state management and error handling. The `ConfirmRemoveMemberDialog` and `BandDetailData.updateName()` patterns have already been proven across multiple phases and mutations — reusing them exactly eliminates the need to debug retry logic, race conditions, or offline gating issues.

---

## Common Pitfalls

### Pitfall 1: Forgetting to bump `_version` on local patches
**What goes wrong:** A local patch updates `inviteCode` while a refresh is in flight. The refresh completes with stale data (old code) and overwrites the newly patched code.

**Why it happens:** The `_version` monotonic counter is a subtle pattern — it's easy to assume "AsyncData update = done" without guarding against concurrent fetches.

**How to avoid:** Every local-patch method in `BandDetailData` and `BandsListData` must open with `_version++` before updating state. See `updateName()` and `renameBand()` — both do this on line 1 of the mutation.

**Warning signs:** User rotates invite code, sees new code briefly, then old code reappears after a background refresh completes.

### Pitfall 2: Trusting transfer response body to patch `ownerId` client-side
**What goes wrong:** Planner creates two patches: (a) invalidate detail for refetch (D-09), and (b) patch list locally using "the target userId we just submitted." If the server rejects the transfer after accepting the request, the list shows the wrong owner.

**Why it happens:** The `TransferBandOwnership` endpoint's `200` response body is empty (per `publicapi.yml:268-286`). Planners often assume "we can trust the value we sent = the new state." With mutations that have no response body, that assumption is dangerous.

**How to avoid:** D-09 is explicit: **always** invalidate the detail provider for a refetch when the response body is empty. The refetch gives the server the final say on ownership. List-side patching (D-10) is done *after* the refetch succeeds, using the refetched `ownerId` as the source of truth (or, safe to do optimistically with known `userId` only because the transfer already succeeded server-side by then — the refetch is in progress).

**Warning signs:** A network glitch causes the transfer API to fail, but the list patch was already done; user sees transferred ownership even though the server rejected it.

### Pitfall 3: Showing owner-controls before profile loads (tri-state ownership)
**What goes wrong:** `isOwner()` returns `false` (because `currentUserId` is null while profile loads), controls are hidden. Profile loads with a different user ID. Controls don't re-render because `isOwner()` comparison is based on identity, not a tri-state change.

**Why it happens:** Boolean logic doesn't capture the "not yet decided" state. `null` from `ownershipStatus()` signals "still loading."

**How to avoid:** Always use `ownershipStatus()` which returns `bool?` (true/false/null). Gate visibility on `isOwner != null`, not just `!isOwner`. The screen already does this (line 122: `if (isOwner != null)`).

**Warning signs:** Owner taps a button that should only be visible to non-owners, or vice versa; controls flicker on and off as profile loads.

### Pitfall 4: Forgetting the self-effect statement in transfer dialog
**What goes wrong:** Dialog reads "Alice will become the owner" — user taps Transfer thinking they're promoting Alice, then realizes *they've* been demoted.

**Why it happens:** The dialog focuses on the target's new state, forgetting to mention the actor's demotion.

**How to avoid:** D-04 is explicit: body text must include "You will no longer be the owner of [band]." This goes in `ConfirmTransferOwnershipDialog`'s content text, not just the title.

**Warning signs:** User transfers ownership, immediately posts in Discord asking "how do I undo that??" — they didn't realize the transfer was permanent and demoting.

### Pitfall 5: Rotating invite code and not showing the new code immediately
**What goes wrong:** User taps Rotate, sees loading spinner, dialog closes, but the code on the screen doesn't change. User taps Rotate again, confused why they got a different code.

**Why it happens:** Planner decides to invalidate and refetch (D-09 refetch pattern) instead of the optimistic local patch (D-08 patch pattern). The refetch takes 500ms–2s; user doesn't see the new code right away.

**How to avoid:** D-08 is explicit: rotate uses a **local optimistic patch** (extract `newInviteCode` from response, call `BandDetailData.rotateInviteCode(newCode)`, patch in-place). No refetch needed because the response body includes the new code. Show snackbar immediately after the patch for confirmation feedback.

**Warning signs:** After rotating, the invite code text doesn't update for 1–2 seconds, or requires a manual refresh to see the new code.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### Ownership Check (Tri-State)
```dart
// Source: VERIFIED: lib/features/bands/band_detail_screen.dart:30-44
static bool isOwner(String? currentUserId, String? ownerId) =>
    currentUserId != null && ownerId != null && currentUserId == ownerId;

static bool? ownershipStatus(
  AsyncValue<Map<String, dynamic>> profileAsync,
  String? ownerId,
) {
  return profileAsync.maybeWhen(
    data: (profile) => isOwner(profile['id'] as String?, ownerId),
    orElse: () => null,
  );
}

// In build():
final profileAsync = ref.watch(profileDataProvider);
final ownerId = band['ownerId'] as String?;
final isOwner = ownershipStatus(profileAsync, ownerId);

// Gate on both the tri-state AND online status:
if (isOwner == true && isOnline) {
  // Show owner-only control
}
if (isOwner != null) {
  // Show ownership status badge (Owner/Member)
}
```

**Why this works:** `isOwner` is null until profile loads, preventing premature render-then-hide. The `maybeWhen` pattern defers decision-making until both profile and band data are available.

### PublicApi Method Pattern (Rotate)
```dart
// Source: VERIFIED: lib/api/public_api.dart:85-91 (createBand template)
// And: lib/api/publicapi.yml:250-264 (RotateBandInviteCode schema)

Future<Map<String, dynamic>> rotateInviteCode(String bandId) async {
  final response = await _client.send(
    'POST',
    '/api/band/$bandId/rotate-invite-code',
  );
  return response!;
}

// Caller extracts newInviteCode:
final response = await ref.read(publicApiProvider).rotateInviteCode(bandId);
final newCode = response['newInviteCode'] as String;
```

**Why this works:** Mirrors `createBand()` pattern — wraps the HTTP response, caller extracts fields. ApiClient already handles auth token injection and 403 auto-logout.

### PublicApi Method Pattern (Transfer)
```dart
// Source: VERIFIED: lib/api/public_api.dart:131-136 (removeMember template)
// And: lib/api/publicapi.yml:268-286 (TransferBandOwnership schema)

Future<void> transferOwnership({
  required String bandId,
  required String userId,
}) async {
  await _client.send(
    'POST',
    '/api/band/$bandId/transfer-ownership',
    body: {'userId': userId},
  );
}

// Caller receives void; uses known userId for list patch:
await ref.read(publicApiProvider).transferOwnership(
  bandId: bandId,
  userId: targetUserId,
);
// No response body to parse; safe to patch list with targetUserId
```

**Why this works:** Mirrors `removeMember()` pattern — void return, named required params. No response body means no echo to validate.

### Local Patch (BandDetailData)
```dart
// Source: VERIFIED: lib/providers/bands_provider.dart:247-255
Future<void> rotateInviteCode(String newCode) async {
  final current = state.valueOrNull;
  if (current == null) return;  // No-op if not loaded
  final updated = {...current, 'inviteCode': newCode};
  _version++;  // Guard against concurrent refreshes
  state = AsyncData(updated);
  await ref.read(cacheServiceProvider).writeBandDetail(bandId, updated);
  ref.read(bandDetailSyncedAtProvider(bandId).notifier).set(DateTime.now());
}
```

**Why this works:** Spread merge is atomic in Dart; `_version++` before state update prevents race-condition overwrites; cache write ensures offline fallback gets the new code; syncedAt bump coordinates with cache invalidation timeline.

### List-Side Patch (BandsListData)
```dart
// Source: VERIFIED: lib/providers/bands_provider.dart:141-152
void patchBandOwner(String bandId, String newOwnerId) {
  final current = state.valueOrNull;
  if (current == null) return;
  final updated = [
    for (final band in current)
      if (band['id'] == bandId)
        {...band, 'ownerId': newOwnerId}
      else
        band,
  ];
  _version++;
  state = AsyncData(updated);
  unawaited(ref.read(cacheServiceProvider).writeBands(updated));
  ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
}
```

**Why this works:** For-loop + spread merge pattern is efficient for large lists; `_version++` same guard; IndexedStack-kept BandsScreen sees the patch immediately (no refetch needed for list).

### Confirmation Dialog Skeleton
```dart
// Source: VERIFIED: lib/features/bands/confirm_remove_member_dialog.dart:13-109
// Template for both ConfirmTransferOwnershipDialog and ConfirmRotateInviteCodeDialog

class ConfirmTransferOwnershipDialog extends ConsumerStatefulWidget {
  const ConfirmTransferOwnershipDialog({
    super.key,
    required this.bandId,
    required this.memberUserId,
    required this.memberUsername,
    required this.bandName,
  });

  final String bandId;
  final String memberUserId;
  final String memberUsername;
  final String bandName;

  @override
  ConsumerState<ConfirmTransferOwnershipDialog> createState() =>
      _ConfirmTransferOwnershipDialogState();
}

class _ConfirmTransferOwnershipDialogState extends ConsumerState<ConfirmTransferOwnershipDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _transfer() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(publicApiProvider).transferOwnership(
        bandId: widget.bandId,
        userId: widget.memberUserId,
      );
      // Post-success mutations (per D-09/D-10):
      ref.invalidate(bandDetailDataProvider(widget.bandId));
      ref.read(bandsListDataProvider.notifier).patchBandOwner(
        widget.bandId,
        widget.memberUserId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      // Optional: ScaffoldMessenger.of(context).showSnackBar(...)
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return AlertDialog(
      title: Text('Transfer ownership to ${widget.memberUsername}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.memberUsername} will become the owner of this band.\n\n'
            'You will no longer be the owner of ${widget.bandName}.',
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        Tooltip(
          message: isOnline ? '' : 'Requires connection',
          child: FilledButton(
            onPressed: (!isOnline || _isSubmitting) ? null : _transfer,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Transfer'),
          ),
        ),
      ],
    );
  }
}
```

**Why this works:** Exact mirror of `ConfirmRemoveMemberDialog`, proven battle-tested. The only change is the title/body text (which must include self-effect per D-04) and the specific API method called.

---

## Validation Architecture

**Framework:** flutter_test (built-in, used throughout project)
**Config file:** analysis_options.yaml (project root)
**Quick run:** `flutter test tests/features/bands/ -k "owner"` (~ 10s for band-related tests)
**Full suite:** `flutter test` (371/371 passing after Phase 07)

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BAND-11 | Rotate button visible to owner only | widget | `flutter test tests/features/bands/band_detail_screen_test.dart -k "rotate"` | ✅ (Phase 6 owner-gate tests exist; new tests for Rotate icon) |
| BAND-11 | New invite code shown immediately after rotate | widget | `flutter test tests/features/bands/confirm_rotate_invite_code_dialog_test.dart -k "success"` | ❌ Wave 0 |
| BAND-11 | Old invite code invalidated server-side | integration | Manual: join with old code after rotate | ❌ Wave 0 |
| BAND-12 | Transfer button visible to owner only | widget | `flutter test tests/features/bands/band_detail_screen_test.dart -k "transfer"` | ✅ (Phase 6 owner-gate tests exist; new tests for Make owner menu item) |
| BAND-12 | New owner sees owner controls after transfer | widget | `flutter test tests/features/bands/confirm_transfer_ownership_dialog_test.dart -k "success"` | ❌ Wave 0 |
| BAND-12 | Old owner sees member controls after transfer | widget | `flutter test tests/features/bands/confirm_transfer_ownership_dialog_test.dart -k "success"` | ❌ Wave 0 |
| BAND-12 | Non-owner never sees either control | widget | `flutter test tests/features/bands/band_detail_screen_test.dart -k "non_owner"` | ✅ (Phase 6 existing) |

### Sampling Rate

- **Per task commit:** `flutter test tests/features/bands/ -k "owner" --coverage` (10s; covers member list + owner-gate logic)
- **Per wave merge:** `flutter test` (full suite, 3–5 min; ensures no cross-feature regressions)
- **Phase gate:** Full suite green (371/371) + manual invite-rotation + manual transfer-ownership sign-off before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/features/bands/confirm_rotate_invite_code_dialog_test.dart` — covers BAND-11 success/error/offline scenarios
- [ ] `tests/features/bands/confirm_transfer_ownership_dialog_test.dart` — covers BAND-12 success/error/offline scenarios
- [ ] `tests/features/bands/band_detail_screen_test.dart` — extend Phase 6 owner-gate tests with new Rotate icon / "Make owner" menu item visibility
- [ ] Framework install: None — flutter_test already in `pubspec.yaml` and `analysis_options.yaml` configured

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

**Existing test structure (Phase 6–7):**
- `tests/features/bands/band_detail_screen_test.dart` — screen rendering, owner-gating, member list
- `tests/features/bands/confirm_remove_member_dialog_test.dart` — dialog state, error handling, API integration
- `tests/providers/bands_provider_test.dart` — BandDetailData/BandsListData local patches, _version guard, cache coordination

New tests follow the same pattern.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | SessionAuth-protected endpoints; ApiClient injects token automatically; 403 triggers auto-logout |
| V3 Session Management | yes | Token-based session; no password required for band mutations; ownership gated server-side (user who is not owner gets 400 error) |
| V4 Access Control | yes | Server enforces owner-only on POST endpoints; client-side owner-gate (tristate check) hides UI only; server is authoritative |
| V5 Input Validation | yes | bandId and userId are UUIDs (schema-enforced); inviteCode is server-generated (no user input); no free-text fields in new endpoints |
| V6 Cryptography | no | Not applicable (no crypto operations in this phase; token persistence already handled Phase 1) |

### Known Threat Patterns for Flutter+Riverpod

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Owner-gate bypass (client-side only) | Elevation of Privilege | Server enforces ownership check (400 error if non-owner); client-side gate is UX only, not a security boundary |
| Timing attack on `isOwner` comparison | Information Disclosure | `currentUserId == ownerId` is a string equality check; no timing sensitivity relevant to auth |
| Cache poisoning after invalid transfer | Tampering | `_version` guard prevents concurrent fetch from overwriting local patch; refetch (D-09) resets on successful transfer |
| Invite code disclosure | Information Disclosure | Code is UI-exposed in plaintext (by design); "Copy" button uses Clipboard API (no logging). Rotation invalidates old code server-side immediately. |

**Summary:** Server-side ownership enforcement is the primary security control. Client-side UI gating (tristate ownership check) is never a security boundary — it's UX only. The API contract (sessionAuth, 400 on non-owner) is the authoritative enforcement point.

---

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Material Icons (`Icons.workspace_premium`, `Icons.refresh`) are available and render as expected in Flutter Material 3 | Code Examples, Design System | Icon doesn't render or renders as placeholder; planner uses fallback icon instead |
| A2 | `PopupMenuButton<int>` implementation with Row children + dividers follows Material Material defaults and renders unclipped | Architecture Patterns | Menu items overflow or clip text at default or max text scale; planner adds widget test to verify |
| A3 | `Clipboard.setData()` has no meaningful failure path on Android/iOS for invite code copy | Don't Hand-Roll | Copy silently fails; users don't notice. Low risk (operation is local, not network-dependent). |
| A4 | Existing `bandDetailDataProvider(bandId).invalidate()` refetch completes within 2–3s on typical network; acceptable for transfer UX | Code Examples, Architecture Patterns | Refetch stalls; transfer dialog stays open for 5+ seconds. User gets frustrated. Planner adds timeout or polling UI. |

**If this table is empty:** Not applicable — all factual claims were verified or cited.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Cache-first serve (load from cache, then fetch if online) | Online-first serve (fetch fresh, then cache-fallback) | Phase 7 (OFFL-07/OFFL-08) | Mutations now assume fresh data; local patches use `_version` guard to prevent stale refetch from clobbering them |
| Standalone TextButton for invite-code copy | IconButton for copy; IconButton for rotate (Invite Code row) | Phase 8 | More compact row; two actions side-by-side; Rotate icon only visible to owner |
| Single person_remove IconButton trailing member row | PopupMenuButton with "Make owner" + "Remove" items | Phase 8 | Consolidates owner actions; "Make owner" clearly distinct from "Remove" via icon/color |

**Deprecated/outdated:**
- `removeMember()` as a standalone UI path (now lives inside PopupMenuButton alongside "Make owner", not as a separate trailing icon)
- Cache-first invalidation patterns (Phase 7 switched to online-first; local patches now guard with `_version`)

---

## Open Questions

None. All API endpoints, schemas, UI patterns, and state-management decisions are documented in CONTEXT.md and locked. Phase 8 is purely additive implementation on a locked design.

---

## Sources

### Primary (HIGH confidence)

- [CONTEXT.md] - Locked implementation decisions D-01 through D-12 (08-band-owner-tools/08-CONTEXT.md)
- [REQUIREMENTS.md] - BAND-11 (rotate invite code), BAND-12 (transfer ownership) acceptance criteria
- [publicapi.yml:250-286] - RotateBandInviteCode and TransferBandOwnership endpoint schemas [VERIFIED: lib/api/publicapi.yml:250-286]
- [band_detail_screen.dart] - Existing member-list rendering, ownership check helpers, invite-code row layout [VERIFIED: lib/features/bands/band_detail_screen.dart:1-280]
- [confirm_remove_member_dialog.dart] - Template for ConfirmTransferOwnershipDialog and ConfirmRotateInviteCodeDialog (dialog state, error handling, loading spinner, offline gating) [VERIFIED: lib/features/bands/confirm_remove_member_dialog.dart:13-109]
- [bands_provider.dart] - BandDetailData.updateName() and BandsListData.renameBand() local-patch patterns [VERIFIED: lib/providers/bands_provider.dart:141-152, 247-255]
- [public_api.dart] - PublicApi method pattern (named params, throw ApiException, return types) [VERIFIED: lib/api/public_api.dart:1-407]
- [config.json] - Validation architecture enabled (nyquist_validation: true) [VERIFIED: .planning/config.json:20-50]

### Secondary (MEDIUM confidence)

- [UI-SPEC.md] - Visual design contract for Phase 8 (already approved; informs testing and styling requirements)
- [STATE.md] - Project state and context history (confirms Phase 7 online-first model precedes Phase 8)
- [CLAUDE.md] - Project conventions (naming, file structure, error handling patterns)

### Tertiary (LOW confidence)

None — all critical findings were verified against authoritative sources (API contract, existing code, design spec).

---

## Metadata

**Confidence breakdown:**

- **Standard stack:** HIGH — All libraries already in use project-wide; no new dependencies; versions verified against `pubspec.lock`
- **Architecture patterns:** HIGH — Both local-patch patterns and dialog template reuse battle-tested code from Phase 2–7
- **Pitfalls:** HIGH — Root causes grounded in existing phase research (WR-02 race conditions, D-09/D-10 invalidation patterns)
- **API contract:** HIGH — Endpoints already defined in publicapi.yml; schemas complete and reviewed in CONTEXT.md
- **UI details:** HIGH — Full design spec in 08-UI-SPEC.md (approved); no ambiguity in icon choice, spacing, or interaction model

**Research date:** 2026-08-21
**Valid until:** 2026-09-04 (14 days — stable domain, no breaking Flutter/Riverpod releases expected)
