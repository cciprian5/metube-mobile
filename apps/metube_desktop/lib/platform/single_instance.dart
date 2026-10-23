import 'dart:io';

import 'package:windows_single_instance/windows_single_instance.dart';

/// Keeps one copy of the app per Windows user: a second start hands its
/// arguments to the first, which comes to the front, and then exits.
///
/// Called **before the window is shown**, so the second copy exits without
/// ever flashing a window.
Future<void> claimSingleInstance(
  List<String> args, {
  void Function(List<String> args)? onSecondStart,
}) => WindowsSingleInstance.ensureSingleInstance(
  args,
  instancePipeName(Platform.environment['USERNAME']),
  onSecondWindow: onSecondStart,
);

/// The pipe the copies talk through, **one per Windows user**.
///
/// Named pipes are machine-wide while the package's lock is per sign-in
/// session, so with one shared name a second user signed in at the same
/// time would find the first user's pipe and hand their arguments to a
/// window in another session. A backslash would end the pipe name early,
/// so the user name is reduced to safe characters.
String instancePipeName(String? user) {
  final safe = (user ?? '').replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  return safe.isEmpty ? 'metube_ember' : 'metube_ember.$safe';
}
