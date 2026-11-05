import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/downloads_data.dart';
import '../../data/local_copies.dart';
import 'add_options.dart';

/// "Then download it to this computer", for the add dialog and the
/// playlist one alike.
abstract final class PullAfter {
  /// The folder to pull into, **asked now** when the user wants to be
  /// asked: the server may take minutes, and a dialog then would come from
  /// nowhere. Null [into] is the download folder; `go` is false when the
  /// folder dialog was closed, and nothing should be sent.
  static Future<({bool go, String? into})> ask(
    WidgetRef ref,
    AddChoice choice,
  ) async {
    if (!choice.pullAfter) return (go: true, into: null);
    if (choice.pullInto case final picked?) return (go: true, into: picked);
    final chosen = await ref
        .read(localCopiesProvider.notifier)
        .chooseDownloadFolder();
    if (chosen.asked && chosen.into == null) return (go: false, into: null);
    return (go: true, into: chosen.asked ? chosen.into : null);
  }

  /// Marks the tasks just sent to come down to this computer when done.
  static void mark(
    WidgetRef ref,
    AddChoice choice,
    String? into,
    Iterable<String> taskIds,
  ) {
    if (!choice.pullAfter) return;
    final pulls = ref.read(pullAfterProvider);
    for (final id in taskIds) {
      pulls[id] = into;
    }
  }
}
