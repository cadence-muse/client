import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/setlists_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
import 'create_setlist_screen.dart';
import 'setlist_detail_screen.dart';
import 'setlist_formatting.dart';

class SetlistListScreen extends ConsumerWidget {
  const SetlistListScreen({super.key, required this.bandId});

  final String bandId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(setlistListDataProvider(bandId));
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      body: setlistsAsync.when(
        data: (setlists) => _buildContent(context, setlists),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          if (error is OfflineNoCacheException) {
            return const OfflineNoCacheView();
          }
          return _buildError(
            context,
            () => ref.invalidate(setlistListDataProvider(bandId)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isOnline
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateSetlistScreen(bandId: bandId),
                ),
              )
            : null,
        tooltip: isOnline ? 'Add setlist' : 'Requires connection',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> setlists,
  ) {
    if (setlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No setlists yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a setlist or ask a bandmate to add one.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateSetlistScreen(bandId: bandId),
                  ),
                ),
                child: const Text('Add setlist'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: setlists.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final setlist = setlists[index];
        final name = setlist['name'] as String;
        final durationSeconds = setlist['durationSeconds'] as int;
        final eventDate = setlist['eventDate'] as String?;
        final eventLocation = setlist['eventLocation'] as String?;
        final colorScheme = Theme.of(context).colorScheme;
        return ListTile(
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(formatEventDate(eventDate)),
          trailing: SizedBox(
            width: 150,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (eventLocation != null) ...[
                  Flexible(
                    child: GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(eventLocation)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              eventLocation,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.timer, size: 18, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  durationSeconds.asMinutesAndSeconds,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SetlistDetailScreen(
                bandId: bandId,
                setlistId: setlist['id'] as String,
              ),
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
            const Text(
              'Failed to load setlists. Tap to try again.',
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
