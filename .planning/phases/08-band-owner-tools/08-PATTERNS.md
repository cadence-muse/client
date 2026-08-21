# Phase 08: Band Owner Tools - Pattern Map

**Mapped:** 2026-08-21
**Files analyzed:** 5 (2 new, 3 modified)
**Analogs found:** 5/5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/bands/confirm_transfer_ownership_dialog.dart` | component | request-response | `lib/features/bands/confirm_remove_member_dialog.dart` | exact |
| `lib/features/bands/confirm_rotate_invite_code_dialog.dart` | component | request-response | `lib/features/bands/confirm_remove_member_dialog.dart` | exact |
| `lib/features/bands/band_detail_screen.dart` | component | request-response | itself (existing file) | self-reference |
| `lib/providers/bands_provider.dart` | provider | CRUD / state-management | itself (existing file) | self-reference |
| `lib/api/public_api.dart` | service | request-response | itself (existing file) | self-reference |

## Pattern Assignments

### `lib/features/bands/confirm_transfer_ownership_dialog.dart` (component, request-response)

**Analog:** `lib/features/bands/confirm_remove_member_dialog.dart`

**Imports pattern** (lines 1-7):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';
```

**Class structure** (lines 13-30):
```dart
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
```

**State management & API call pattern** (lines 32-60):
```dart
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
      // Post-success mutations (D-09/D-10):
      ref.invalidate(bandDetailDataProvider(widget.bandId));
      ref.read(bandsListDataProvider.notifier).patchBandOwner(
        widget.bandId,
        widget.memberUserId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
```

**UI pattern with offline gating** (lines 63-107):
```dart
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

---

### `lib/features/bands/confirm_rotate_invite_code_dialog.dart` (component, request-response)

**Analog:** `lib/features/bands/confirm_remove_member_dialog.dart`

**Imports pattern** (lines 1-7):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';
```

**Class structure** (lines 13-30):
```dart
class ConfirmRotateInviteCodeDialog extends ConsumerStatefulWidget {
  const ConfirmRotateInviteCodeDialog({
    super.key,
    required this.bandId,
    required this.bandName,
  });

  final String bandId;
  final String bandName;

  @override
  ConsumerState<ConfirmRotateInviteCodeDialog> createState() =>
      _ConfirmRotateInviteCodeDialogState();
}
```

**State management & API call pattern** (lines 32-60):
```dart
class _ConfirmRotateInviteCodeDialogState extends ConsumerState<ConfirmRotateInviteCodeDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _rotate() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(publicApiProvider).rotateInviteCode(widget.bandId);
      final newCode = response['newInviteCode'] as String;
      
      // Post-success: optimistic patch (D-08)
      await ref.read(bandDetailDataProvider(widget.bandId).notifier).rotateInviteCode(newCode);
      
      if (!mounted) return;
      Navigator.of(context).pop();
      // Show snackbar confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite code rotated')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
```

**UI pattern** (lines 63-107):
```dart
  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    return AlertDialog(
      title: Text('Rotate invite code for ${widget.bandName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The current invite code will stop working immediately. Anyone who '
            'hasn\'t used it to join will need a new code to access this band.',
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
            onPressed: (!isOnline || _isSubmitting) ? null : _rotate,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Rotate'),
          ),
        ),
      ],
    );
  }
}
```

---

### `lib/features/bands/band_detail_screen.dart` (component, request-response)

**Analog:** itself (existing file)

**Ownership check helpers** (lines 30-44):
```dart
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
```

**Member list rendering with PopupMenuButton** (lines 145-180):
Replace the current single `IconButton` with `PopupMenuButton`:
```dart
final showMenu = isOwner == true && memberUserId != null && memberUserId != ownerId;

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
                    Icon(Icons.workspace_premium),  // "Make owner" icon
                    const SizedBox(width: 8),
                    const Text('Make owner'),
                  ],
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => ConfirmTransferOwnershipDialog(
                    bandId: bandId,
                    memberUserId: memberUserId,
                    memberUsername: memberUsername,
                    bandName: name,
                  ),
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
                  builder: (_) => ConfirmRemoveMemberDialog(
                    bandId: bandId,
                    memberUserId: memberUserId,
                    memberUsername: memberUsername,
                    bandName: name,
                  ),
                ),
              ),
            ],
          ),
        )
      : null,
);
```

**Invite code row with Copy + Rotate icons** (lines 189-205):
Replace the current `TextButton` with two `IconButton`s:
```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Row(
    children: [
      Expanded(
        child: Text(
          inviteCode,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
      Tooltip(
        message: isOnline ? '' : 'Requires connection',
        child: IconButton(
          icon: const Icon(Icons.content_copy),
          onPressed: isOnline ? () => _copyInviteCode(context, inviteCode) : null,
        ),
      ),
      if (isOwner == true)
        Tooltip(
          message: isOnline ? '' : 'Requires connection',
          child: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isOnline
                ? () => showDialog<void>(
                    context: context,
                    builder: (_) => ConfirmRotateInviteCodeDialog(
                      bandId: bandId,
                      bandName: name,
                    ),
                  )
                : null,
          ),
        ),
    ],
  ),
),
```

---

### `lib/providers/bands_provider.dart` (provider, CRUD / state-management)

**Analog:** itself (existing file)

**BandsListData.renameBand() pattern** (lines 141-152):
```dart
void renameBand(String bandId, String newName) {
  final current = state.valueOrNull;
  if (current == null) return;
  final updated = [
    for (final band in current)
      if (band['id'] == bandId) {...band, 'name': newName} else band,
  ];
  _version++;
  state = AsyncData(updated);
  unawaited(ref.read(cacheServiceProvider).writeBands(updated));
  ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
}
```

**New BandsListData.patchBandOwner() method** (to add, follows same pattern):
```dart
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

**BandDetailData.updateName() pattern** (lines 247-255):
```dart
Future<void> updateName(String newName) async {
  final current = state.valueOrNull;
  if (current == null) return;
  final updated = {...current, 'name': newName};
  _version++;
  state = AsyncData(updated);
  await ref.read(cacheServiceProvider).writeBandDetail(bandId, updated);
  ref.read(bandDetailSyncedAtProvider(bandId).notifier).set(DateTime.now());
}
```

**New BandDetailData.rotateInviteCode() method** (to add, follows same pattern):
```dart
Future<void> rotateInviteCode(String newCode) async {
  final current = state.valueOrNull;
  if (current == null) return;
  final updated = {...current, 'inviteCode': newCode};
  _version++;
  state = AsyncData(updated);
  await ref.read(cacheServiceProvider).writeBandDetail(bandId, updated);
  ref.read(bandDetailSyncedAtProvider(bandId).notifier).set(DateTime.now());
}
```

---

### `lib/api/public_api.dart` (service, request-response)

**Analog:** itself (existing file)

**PublicApi.removeMember() pattern** (lines 131-136):
```dart
Future<void> removeMember({
  required String bandId,
  required String userId,
}) async {
  await _client.send('DELETE', '/api/band/$bandId/remove-member/$userId');
}
```

**New PublicApi.transferOwnership() method** (to add, follows removeMember pattern):
```dart
/// Transfers band ownership to another member. Server-enforced owner-only
/// (see `TransferBandOwnership` in `publicapi.yml`); `'200'` no content.
/// Client performs invalidate + refetch after success (D-09).
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
```

**PublicApi.createBand() pattern** (lines 85-92):
```dart
Future<Map<String, dynamic>> createBand({required String name}) async {
  final response = await _client.send(
    'POST',
    '/api/band',
    body: {'name': name},
  );
  return response!;
}
```

**New PublicApi.rotateInviteCode() method** (to add, follows createBand pattern):
```dart
/// Rotates the band's invite code, returning the new code immediately.
/// Server-enforced owner-only (see `RotateBandInviteCode` in `publicapi.yml`);
/// `'200'` with `RotateBandInviteCodeResponseBody` containing the new code.
/// Client performs optimistic local patch (D-08).
Future<Map<String, dynamic>> rotateInviteCode(String bandId) async {
  final response = await _client.send(
    'POST',
    '/api/band/$bandId/rotate-invite-code',
  );
  return response!;
}
```

---

## Shared Patterns

### ConsumerStatefulWidget Dialog Template
**Source:** `lib/features/bands/confirm_remove_member_dialog.dart` (lines 13-109)
**Apply to:** All new confirmation dialogs (ConfirmTransferOwnershipDialog, ConfirmRotateInviteCodeDialog)

Pattern:
- Extends `ConsumerStatefulWidget` (Riverpod integration)
- Stores `_isSubmitting` and `_errorMessage` as local state
- Try/catch ApiException with inline error display
- Uses `Tooltip(message: isOnline ? '' : 'Requires connection')` for offline gating
- FilledButton disabled when `!isOnline || _isSubmitting`
- Circular spinner shown during submission
- Dialog stays open on error for retry

### Local Patch Pattern (State Mutation)
**Source:** `lib/providers/bands_provider.dart`
  - BandsListData.renameBand() (lines 141-152) for list-side patches
  - BandDetailData.updateName() (lines 247-255) for detail-side patches

Pattern:
- Get current state via `state.valueOrNull`
- Early return if null (not loaded yet)
- Spread-merge new field: `{...current, 'field': newValue}`
- **Always bump `_version++` before state assignment** (guards against concurrent fetch race conditions)
- Assign to `state = AsyncData(updated)`
- Write to cache service (await for detail, unawaited for list)
- Bump syncedAt timestamp via provider notifier

### Ownership Check (Tri-State)
**Source:** `lib/features/bands/band_detail_screen.dart` (lines 30-44)
**Apply to:** All owner-gated UI controls

Pattern:
- `isOwner(String? currentUserId, String? ownerId)` returns bool (definitive comparison)
- `ownershipStatus(AsyncValue<Map>, String? ownerId)` returns bool? (tri-state: true/false/null)
- Use `ownershipStatus()` result to gate visibility: `if (isOwner == true)` shows control, `if (isOwner != null)` shows status badge
- Never render then hide — `null` state prevents flickering

---

## No Analog Found

None — all files have close existing analogs in the codebase. All new files follow established patterns from Phase 2–7.

## Metadata

**Analog search scope:** `lib/features/bands/`, `lib/providers/`, `lib/api/`
**Files scanned:** 5 primary (confirm_*.dart, band_detail_screen.dart, bands_provider.dart, public_api.dart)
**Pattern extraction date:** 2026-08-21
**Confidence:** HIGH — All analogs verified against actual codebase; patterns battle-tested across Phase 2–7
