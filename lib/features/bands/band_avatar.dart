import 'package:flutter/material.dart';

/// Avatar for a band list row: a colored circle with the band name's first
/// letter. The background color is picked deterministically from
/// [bandName]'s hash, so the same band name always renders the same color.
///
/// Kept as its own widget (rather than inlined into the list tile) so a
/// later milestone can swap in a real image avatar by editing only this
/// file.
class BandAvatar extends StatelessWidget {
  const BandAvatar({super.key, required this.bandName});

  final String bandName;

  static const _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
    Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[bandName.hashCode.abs() % _colors.length];
    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        bandName.isEmpty ? '?' : bandName[0].toUpperCase(),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
