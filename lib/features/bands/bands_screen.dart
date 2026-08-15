import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bands_provider.dart';
import 'band_avatar.dart';
import 'band_detail_screen.dart';

class BandsScreen extends ConsumerWidget {
  const BandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandsAsync = ref.watch(bandsListDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bands')),
      body: bandsAsync.when(
        data: (bands) => _buildContent(context, bands),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildError(context, () => ref.invalidate(bandsListDataProvider)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> bands,
  ) {
    if (bands.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No bands yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a band or ask a bandmate for an invite code to '
                'join one.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: bands.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final band = bands[index];
        final name = band['name'] as String;
        return ListTile(
          leading: BandAvatar(bandName: name),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BandDetailScreen(bandId: band['id'] as String),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load bands",
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
