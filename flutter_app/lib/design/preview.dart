// Scratch visual smoke test — NOT the app entry point. Swap the `body:`
// below to whatever tab/widget needs a quick look; don't wire real app state
// through here, main.dart owns that.
// Run with: flutter run -d windows -t lib/design/preview.dart
import 'package:flutter/material.dart';

import '../tabs/devices_tab.dart';
import 'design.dart';

void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: CharonTheme.dark(),
      home: CharonNavShell(
        selectedIndex: _selected,
        onSelect: (i) => setState(() => _selected = i),
        body: const DevicesTab(),
      ),
    );
  }
}
