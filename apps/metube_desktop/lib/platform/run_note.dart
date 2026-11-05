import 'dart:io';

import 'package:mt_core/mt_core.dart';

/// **How the last run ended**, written to the log as this one starts.
///
/// A native crash reaches no Dart handler, so the log used to stop in
/// mid-sentence with nothing to tell it from the user closing the window.
/// A file marks a run as open until it closes; the runner
/// (`windows/runner/run_note.cpp`) leaves a second one when it crashes,
/// naming the code and the module.
class RunNote {
  RunNote({required String folder, required this.logger})
    : _open = File('$folder/$openName'),
      _crash = File('$folder/$crashName');

  static const openName = 'ember.running';
  static const crashName = 'last_crash.txt';

  /// The runner writes one short line; anything longer is not its own.
  static const _longestNote = 300;

  final MTLogger logger;
  final File _open;
  final File _crash;

  /// Says how the last run ended, and marks this one as open. Called once
  /// this process knows it is the only one, or a second start would read the
  /// first's mark as a run that never closed.
  Future<void> begin() async {
    try {
      final leftOpen = await _open.exists();
      if (await _crash.exists()) {
        final note = (await _crash.readAsString()).trim();
        final shown = note.length > _longestNote
            ? note.substring(0, _longestNote)
            : note;
        await logger.error('the last run crashed: $shown', tag: 'crash');
        await _crash.delete();
      } else if (leftOpen) {
        await logger.log(
          'the last run ended without closing',
          level: LogLevel.warn,
          tag: 'app',
        );
      }
      await _open.parent.create(recursive: true);
      await _open.writeAsString('$pid');
    } on Exception {
      // A note for diagnosis is never worth stopping the app over.
    }
  }

  /// The run is closing by itself.
  Future<void> end() async {
    try {
      await logger.log('app closed', tag: 'app');
      if (await _open.exists()) await _open.delete();
    } on Exception {
      // As above: the next start only reports one false ending.
    }
  }
}
