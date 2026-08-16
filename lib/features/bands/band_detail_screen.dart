import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bands_provider.dart';
import '../../providers/profile_provider.dart';
import '../tracks/track_list_screen.dart';
import 'band_avatar.dart';
import 'confirm_delete_band_dialog.dart';
import 'confirm_leave_band_dialog.dart';
import 'confirm_remove_member_dialog.dart';
import 'edit_band_screen.dart';

class BandDetailScreen extends ConsumerWidget {
  const BandDetailScreen({super.key, required this.bandId});

  final String bandId;

  /// `true` only when [currentUserId] (from `profileDataProvider`, once
  /// loaded) equals [ownerId] (from `BandDetailData`) — both server-returned
  /// values, never a client-supplied id (D-01/D-02). Returns `false` (not a
  /// crash) for a `null` [currentUserId], which happens while the profile is
  /// still loading — callers must additionally gate on profile-loaded state
  /// via [_ownershipStatus] so a `false` here (unresolved) isn't confused
  /// with a definite "not the owner" (RESEARCH.md Pitfall 2).
  static bool _isOwner(String? currentUserId, String? ownerId) =>
      currentUserId != null && ownerId != null && currentUserId == ownerId;

  /// Tri-state ownership: `true` (owner), `false` (member, resolved), or
  /// `null` (profile hasn't loaded yet — owner-only/member-only actions must
  /// stay hidden, never optimistically rendered then hidden).
  static bool? _ownershipStatus(
    AsyncValue<Map<String, dynamic>> profileAsync,
    String? ownerId,
  ) {
    return profileAsync.maybeWhen(
      data: (profile) => _isOwner(profile['id'] as String?, ownerId),
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandAsync = ref.watch(bandDetailDataProvider(bandId));
    final profileAsync = ref.watch(profileDataProvider);
    final bandName = bandAsync.valueOrNull?['name'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(bandName ?? 'Band'),
        actions: [
          if (bandName != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      EditBandScreen(bandId: bandId, currentName: bandName),
                ),
              ),
            ),
        ],
      ),
      body: bandAsync.when(
        data: (band) => _buildContent(context, band, profileAsync),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(bandDetailDataProvider(bandId)),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, dynamic> band,
    AsyncValue<Map<String, dynamic>> profileAsync,
  ) {
    final name = band['name'] as String;
    final ownerId = band['ownerId'] as String?;
    final members = (band['members'] as List).cast<Map<String, dynamic>>();
    final inviteCode = (band['inviteCode'] as String).trim();
    final isOwner = _ownershipStatus(profileAsync, ownerId);

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
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Members',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No members'),
          )
        else
          ...members.map((member) {
            final memberUserId = member['id'] as String?;
            final memberUsername = member['username'] as String;
            // Owner-only, and never shown on the owner's own row — that's
            // what "Delete"/"Leave" are for (D-02, D-08 edge probe:
            // adjacency — targets member['id'], never a username match).
            final showRemove =
                isOwner == true &&
                memberUserId != null &&
                memberUserId != ownerId;
            return ListTile(
              title: Text(memberUsername),
              trailing: showRemove
                  ? IconButton(
                      icon: Icon(
                        Icons.person_remove,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      tooltip: 'Remove',
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => ConfirmRemoveMemberDialog(
                          bandId: bandId,
                          memberUserId: memberUserId,
                          memberUsername: memberUsername,
                          bandName: name,
                        ),
                      ),
                    )
                  : null,
            );
          }),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Invite code',
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
              TextButton(
                onPressed: () => _copyInviteCode(context, inviteCode),
                child: const Text('Copy'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.music_note),
          title: const Text('Tracks'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackListScreen(bandId: bandId),
            ),
          ),
        ),
        if (isOwner == true) ...[
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  ConfirmDeleteBandDialog(bandId: bandId, bandName: name),
            ),
          ),
        ],
        if (isOwner == false) ...[
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Leave',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  ConfirmLeaveBandDialog(bandId: bandId, bandName: name),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _copyInviteCode(BuildContext context, String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied!')));
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load band details",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
