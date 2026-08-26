import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
import '../setlists/setlist_list_screen.dart';
import '../tracks/track_list_screen.dart';
import 'band_avatar.dart';
import 'confirm_delete_band_dialog.dart';
import 'confirm_leave_band_dialog.dart';
import 'confirm_remove_member_dialog.dart';
import 'confirm_rotate_invite_code_dialog.dart';
import 'confirm_transfer_ownership_dialog.dart';
import 'edit_band_screen.dart';

class BandDetailScreen extends ConsumerWidget {
  const BandDetailScreen({super.key, required this.bandId});

  final String bandId;

  /// `true` only when [currentUserId] (from `profileDataProvider`, once
  /// loaded) equals [ownerId] (from `BandDetailData`) — both server-returned
  /// values, never a client-supplied id (D-01/D-02). Returns `false` (not a
  /// crash) for a `null` [currentUserId], which happens while the profile is
  /// still loading — callers must additionally gate on profile-loaded state
  /// via [ownershipStatus] so a `false` here (unresolved) isn't confused
  /// with a definite "not the owner" (RESEARCH.md Pitfall 2).
  static bool isOwner(String? currentUserId, String? ownerId) =>
      currentUserId != null && ownerId != null && currentUserId == ownerId;

  /// Tri-state ownership: `true` (owner), `false` (member, resolved), or
  /// `null` (profile hasn't loaded yet — owner-only/member-only actions must
  /// stay hidden, never optimistically rendered then hidden).
  static bool? ownershipStatus(
    AsyncValue<Map<String, dynamic>> profileAsync,
    String? ownerId,
  ) {
    return profileAsync.maybeWhen(
      data: (profile) => isOwner(profile['id'] as String?, ownerId),
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bandAsync = ref.watch(bandDetailDataProvider(bandId));
    final profileAsync = ref.watch(profileDataProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final bandName = bandAsync.valueOrNull?['name'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(bandName ?? l10n.bandDetailFallbackTitle),
        actions: [
          if (bandName != null)
            Tooltip(
              message: isOnline ? l10n.commonEdit : l10n.commonRequiresConnection,
              child: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: isOnline
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditBandScreen(
                            bandId: bandId,
                            currentName: bandName,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
        ],
      ),
      body: bandAsync.when(
        data: (band) => _buildContent(context, band, profileAsync, isOnline),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          if (error is OfflineNoCacheException) {
            return const OfflineNoCacheView();
          }
          return _buildError(
            context,
            () => ref.invalidate(bandDetailDataProvider(bandId)),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> band,
    AsyncValue<Map<String, dynamic>> profileAsync,
    bool isOnline,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final name = band['name'] as String;
    final ownerId = band['ownerId'] as String?;
    final members = (band['members'] as List).cast<Map<String, dynamic>>();
    final inviteCode = (band['inviteCode'] as String).trim();
    final isOwner = ownershipStatus(profileAsync, ownerId);

    return ListView(
      children: [
        const SizedBox(height: 24),
        Center(child: BandAvatar(bandName: name)),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (isOwner != null) ...[
          Center(
            child: Text(
              '${isOwner ? l10n.bandRoleOwner : l10n.bandRoleMember} • '
              '${l10n.memberCount(members.length)}',
            ),
          ),
          const SizedBox(height: 24),
        ],
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.bandDetailMembersHeader,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.bandDetailNoMembers),
          )
        else
          ...members.map((member) {
            final memberUserId = member['id'] as String?;
            final memberUsername = member['username'] as String;
            // Owner-only, and never shown on the owner's own row — that's
            // what "Delete"/"Leave" are for (D-01/D-02, D-08 edge probe:
            // adjacency — targets member['id'], never a username match).
            final showMenu =
                isOwner == true &&
                memberUserId != null &&
                memberUserId != ownerId;
            return ListTile(
              title: Text(memberUsername),
              trailing: showMenu
                  ? Tooltip(
                      message: isOnline ? '' : l10n.commonRequiresConnection,
                      child: PopupMenuButton<void>(
                        enabled: isOnline,
                        itemBuilder: (context) => [
                          PopupMenuItem<void>(
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (_) => ConfirmTransferOwnershipDialog(
                                bandId: bandId,
                                memberUserId: memberUserId,
                                memberUsername: memberUsername,
                                bandName: name,
                              ),
                            ),
                            // No mainAxisSize.min here (unlike a typical
                            // fixed-content Row) — the PopupMenu overlay
                            // caps its own width well below what "Make
                            // owner" needs at large OS text-scale settings,
                            // so the label is wrapped in Expanded to let it
                            // wrap onto a second line instead of
                            // overflowing horizontally (UI-SPEC E1 backstop
                            // truths).
                            child: Row(
                              children: [
                                const Icon(Icons.workspace_premium),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(l10n.bandDetailMakeOwnerAction),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<void>(
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (_) => ConfirmRemoveMemberDialog(
                                bandId: bandId,
                                memberUserId: memberUserId,
                                memberUsername: memberUsername,
                                bandName: name,
                              ),
                            ),
                            // Same wrap-not-overflow reasoning as the "Make
                            // owner" item above.
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_remove,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.commonRemove,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            );
          }),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.bandDetailInviteCodeHeader,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
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
                message: isOnline
                    ? l10n.bandDetailCopyTooltip
                    : l10n.commonRequiresConnection,
                child: IconButton(
                  icon: const Icon(Icons.content_copy),
                  onPressed: isOnline
                      ? () => _copyInviteCode(context, inviteCode)
                      : null,
                ),
              ),
              if (isOwner == true)
                Tooltip(
                  message: isOnline
                      ? l10n.commonRotate
                      : l10n.commonRequiresConnection,
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
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(l10n.navTracks),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackListScreen(bandId: bandId),
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.playlist_play),
          title: Text(l10n.navSetlists),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SetlistListScreen(bandId: bandId),
            ),
          ),
        ),
        if (isOwner == true) ...[
          const Divider(height: 1),
          Tooltip(
            message: isOnline ? '' : l10n.commonRequiresConnection,
            child: ListTile(
              enabled: isOnline,
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.commonDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: isOnline
                  ? () => showDialog<void>(
                      context: context,
                      builder: (_) => ConfirmDeleteBandDialog(
                        bandId: bandId,
                        bandName: name,
                      ),
                    )
                  : null,
            ),
          ),
        ],
        if (isOwner == false) ...[
          const Divider(height: 1),
          Tooltip(
            message: isOnline ? '' : l10n.commonRequiresConnection,
            child: ListTile(
              enabled: isOnline,
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.commonLeave,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: isOnline
                  ? () => showDialog<void>(
                      context: context,
                      builder: (_) => ConfirmLeaveBandDialog(
                        bandId: bandId,
                        bandName: name,
                      ),
                    )
                  : null,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _copyInviteCode(BuildContext context, String inviteCode) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.bandDetailCopiedSnackbar)));
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.bandDetailErrorTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.commonConnectionError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
