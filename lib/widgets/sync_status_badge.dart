import 'dart:async';

import 'package:flutter/material.dart';

/// D-07: shared staleness indicator placed below a screen's AppBar, above
/// its content. Renders a single scalar [syncedAt] value passed in by the
/// caller — no independent loading state, no ordering/sort-stability
/// behavior (see plain [StatefulWidget], not a `Consumer`).
class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key, required this.syncedAt});

  final DateTime? syncedAt;

  /// D-09: hidden below this age (`<`, not `<=` — appears exactly at 10m).
  static const hiddenThreshold = Duration(minutes: 10);

  /// D-08: warning-color escalation at/above this age (`>=` — exactly 30m
  /// escalates). Independent constant from [hiddenThreshold], never
  /// collapsed into one number.
  static const warningThreshold = Duration(minutes: 30);

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncedAt = widget.syncedAt;
    if (syncedAt == null) {
      return const SizedBox.shrink();
    }

    final age = DateTime.now().difference(syncedAt);
    if (age < SyncStatusBadge.hiddenThreshold) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isWarning = age >= SyncStatusBadge.warningThreshold;
    final color = isWarning ? colorScheme.error : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWarning ? Icons.warning_amber : Icons.cloud_done,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text('Synced ${age.inMinutes}m ago', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
