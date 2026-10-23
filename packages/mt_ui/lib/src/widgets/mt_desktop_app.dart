import 'package:flutter/widgets.dart';

/// Declares the app beneath it to be the Windows app.
///
/// **Only the Windows app places this**, above its `MaterialApp`. It is a
/// policy, not a platform check: layouts ask [isDesktop] (through
/// `context.windowClass`) rather than `Platform.isWindows`, so a widget test
/// can stand in either app, and the phone apps, which never place it, can
/// never take a desktop branch whatever their window size.
class MTDesktopApp extends InheritedWidget {
  const MTDesktopApp({super.key, required super.child});

  static bool isDesktop(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MTDesktopApp>() != null;

  @override
  bool updateShouldNotify(MTDesktopApp oldWidget) => false;
}
