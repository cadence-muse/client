import 'package:flutter/material.dart';

import 'band.dart';

class BandsScreen extends StatelessWidget {
  const BandsScreen({super.key});

  static const _mockBands = [
    Band(name: 'B.A.T.H.', genre: 'Thrash metal', memberCount: 5),
    Band(name: 'Devil in I', genre: 'Alternative metal', memberCount: 4),
    Band(name: 'Ostego', genre: 'Metalcore', memberCount: 5),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bands')),
      body: ListView.separated(
        itemCount: _mockBands.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final band = _mockBands[index];
          return ListTile(
            leading: CircleAvatar(child: Text(band.name[0])),
            title: Text(band.name),
            subtitle: Text('${band.genre} · ${band.memberCount} members'),
          );
        },
      ),
    );
  }
}
