import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// A bare shell that proves the workspace builds for Windows with the
/// shared packages; the real bootstrap (storage, player, window) replaces it.
///
/// `--gallery` opens the Wahaj component sheet for review by eye, with
/// `--night` and `--ltr` for the other theme and direction.
void main(List<String> args) {
  registerMTIconLicenses();
  runApp(
    EmberApp(
      gallery: args.contains('--gallery'),
      night: args.contains('--night'),
      arabic: !args.contains('--ltr'),
    ),
  );
}

class EmberApp extends StatelessWidget {
  const EmberApp({
    super.key,
    this.gallery = false,
    this.night = false,
    this.arabic = true,
  });

  final bool gallery;
  final bool night;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    // Declares this the Windows app, the only place that does, so shared
    // layouts may take their desktop branch here and never on a phone.
    return MTDesktopApp(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
        darkTheme: mtDesktopTheme(MTVariant.superApp, Brightness.dark),
        themeMode: night ? ThemeMode.dark : ThemeMode.light,
        home: gallery ? MTWahajGallery(arabic: arabic) : const Scaffold(),
      ),
    );
  }
}
