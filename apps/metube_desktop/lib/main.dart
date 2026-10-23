import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// A bare shell that proves the workspace builds for Windows with the
/// shared packages; the real bootstrap (storage, player, window) replaces it.
void main() {
  runApp(const EmberApp());
}

class EmberApp extends StatelessWidget {
  const EmberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      darkTheme: mtTheme(MTVariant.superApp, Brightness.dark),
      home: const Scaffold(),
    );
  }
}
