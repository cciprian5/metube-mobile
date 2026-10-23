import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import 'identity.dart';
import 'router.dart';
import 'shell/ember_shell.dart';

/// The MeTube Ember root: the Wahaj desktop theme in Super's identity,
/// following Windows between day and night, plus localisation and the
/// router.
class EmberApp extends StatefulWidget {
  const EmberApp({super.key, this.router});

  /// For tests; the app builds its own otherwise.
  final GoRouter? router;

  @override
  State<EmberApp> createState() => _EmberAppState();
}

class _EmberAppState extends State<EmberApp> {
  // Built once for the life of the app: a router rebuilt with the widget
  // would reset the navigation and everything living under the shell.
  late final GoRouter _router =
      widget.router ??
      buildEmberRouter(
        shell: (_, state, child) =>
            EmberShell(location: state.uri, child: child),
      );

  @override
  Widget build(BuildContext context) {
    // Declares this the Windows app, the only place that does, so shared
    // layouts may take their desktop branch here and never on a phone.
    return MTDesktopApp(
      child: MaterialApp.router(
        title: EmberIdentity.displayName,
        debugShowCheckedModeBanner: false,
        theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
        darkTheme: mtDesktopTheme(MTVariant.superApp, Brightness.dark),
        themeMode: ThemeMode.system,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        localeListResolutionCallback: mtLocaleResolution,
        routerConfig: _router,
      ),
    );
  }
}

/// The Wahaj component sheet for review by eye (`--gallery`, with
/// `--night` and `--ltr`), outside the app's storage and player.
class EmberGalleryApp extends StatelessWidget {
  const EmberGalleryApp({super.key, this.night = false, this.arabic = true});

  final bool night;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    return MTDesktopApp(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
        darkTheme: mtDesktopTheme(MTVariant.superApp, Brightness.dark),
        themeMode: night ? ThemeMode.dark : ThemeMode.light,
        home: MTWahajGallery(arabic: arabic),
      ),
    );
  }
}
