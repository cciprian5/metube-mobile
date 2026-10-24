import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import 'sync_data.dart';

/// What runs as the window closes, after the player is saved; main runs
/// them, each within the window's own time limit.
final beforeCloseProvider = Provider<List<Future<void> Function()>>(
  (ref) => [],
);

/// How often a local change is looked for, and every how many looks the
/// positions count too: a position moves every few seconds while a clip
/// plays, and the folder should not be rewritten that often.
const syncLook = Duration(seconds: 5);
const syncPositionsEvery = 6;

/// How long the folder must be still before another device's change is
/// read: a sync program writes a file in several steps.
const syncSettle = Duration(seconds: 2);

/// **Keeps the sync running while it is on**, watched by the shell:
///
/// - once at the start, and whenever another device's file in the folder
///   changes (this computer's own writes are not news);
/// - when something here changed: tags, favourites, lists and searches
///   within [syncLook], positions within [syncLook] × [syncPositionsEvery];
/// - once more as the window closes, so the last position is not lost.
final syncRunnerProvider = Provider<void>((ref) {
  final settings = ref.watch(syncSettingsProvider).valueOrNull;
  if (settings == null || !settings.on) return;
  final sync = ref.read(emberSyncProvider);
  final folder = SyncFolder(settings.folder!);
  final mine = folder.deviceDir(settings.deviceId!).path.toLowerCase();

  Timer? settle;
  void soon() {
    settle?.cancel();
    settle = Timer(syncSettle, () => unawaited(sync.run()));
  }

  StreamSubscription<FileSystemEvent>? watching;
  Future<void> watch() async {
    try {
      await folder.root.create(recursive: true);
      watching = folder.root.watch(recursive: true).listen(
        (event) {
          if (!event.path.toLowerCase().startsWith(mine)) soon();
        },
        // A folder on a drive that went away; the timer still runs.
        onError: (Object _) {},
      );
    } on FileSystemException {
      // The same; the next look tries the folder again.
    }
  }

  String? quiet;
  String? whole;
  var looks = 0;
  Future<void> look() async {
    looks++;
    final now = await sync.localPrint(withPositions: false);
    var changed = quiet != null && now != quiet;
    quiet = now;
    if (looks % syncPositionsEvery == 0) {
      final all = await sync.localPrint();
      changed = changed || (whole != null && all != whole);
      whole = all;
    }
    if (changed) await sync.run();
  }

  unawaited(sync.run());
  unawaited(watch());
  final timer = Timer.periodic(syncLook, (_) => unawaited(look()));
  final hooks = ref.read(beforeCloseProvider);
  Future<void> last() => sync.run();
  hooks.add(last);
  ref.onDispose(() {
    timer.cancel();
    settle?.cancel();
    unawaited(watching?.cancel());
    hooks.remove(last);
  });
});
