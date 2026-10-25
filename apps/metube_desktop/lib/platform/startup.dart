import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

import '../identity.dart';

/// **Starting with Windows**: the app on the user's own start-up list
/// (no administrator), started with [arg] so it opens out of the way.
class WindowsStartup {
  WindowsStartup() {
    launchAtStartup.setup(
      appName: EmberIdentity.displayName,
      appPath: Platform.resolvedExecutable,
      args: const [arg],
    );
  }

  /// What the start-up list starts the app with.
  static const arg = '--startup';

  /// Whether the list has the app now; the user may have taken it off in
  /// Task Manager.
  Future<bool> isOn() async {
    try {
      return await launchAtStartup.isEnabled();
    } on Object {
      return false;
    }
  }

  /// True when the list now says [on].
  Future<bool> set(bool on) async {
    try {
      on ? await launchAtStartup.enable() : await launchAtStartup.disable();
      return await isOn() == on;
    } on Object {
      return false;
    }
  }
}
