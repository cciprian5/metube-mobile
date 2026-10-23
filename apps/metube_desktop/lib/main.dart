import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// A bare shell that proves the workspace builds for Windows with the
/// shared packages; the real bootstrap (storage, player, window) replaces it.
void main() {
  registerMTIconLicenses();
  runApp(const EmberApp());
}

class EmberApp extends StatelessWidget {
  const EmberApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Declares this the Windows app, the only place that does, so shared
    // layouts may take their desktop branch here and never on a phone.
    return MTDesktopApp(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: mtTheme(
          MTVariant.superApp,
          Brightness.light,
          type: MTTypeScale.desktop,
        ),
        darkTheme: mtTheme(
          MTVariant.superApp,
          Brightness.dark,
          type: MTTypeScale.desktop,
        ),
        home: const Scaffold(),
      ),
    );
  }
}
