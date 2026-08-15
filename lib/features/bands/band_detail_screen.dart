import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bands_provider.dart';
import 'band_avatar.dart';
import 'edit_band_screen.dart';

class BandDetailScreen extends ConsumerWidget {
  const BandDetailScreen({super.key, required this.bandId});

  final String bandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandAsync = ref.watch(bandDetailDataProvider(bandId));
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
        data: (band) => _buildContent(context, band),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(
          context,
          () => ref.invalidate(bandDetailDataProvider(bandId)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> band) {
    final name = band['name'] as String;
    final members = (band['members'] as List).cast<Map<String, dynamic>>();
    final inviteCode = (band['inviteCode'] as String).trim();

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
          ...members.map(
            (member) => ListTile(title: Text(member['username'] as String)),
          ),
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
