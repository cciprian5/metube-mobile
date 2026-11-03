import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart' show mtLocalizationsFor;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../di.dart';
import '../home/background_hold.dart';
import '../home/download_watcher.dart' show notificationsProvider;
import '../shared/error_report.dart';
import 'library_actions.dart';
import 'share_job.dart';

export 'share_job.dart';

/// The notice that a copy finished, or failed, while the app was away.
const shareNotificationId = 770002;

/// A clip this large asks before it downloads: on mobile data one stray
/// tap would otherwise cost the whole file.
const shareConfirmBytes = 500 * 1024 * 1024;

typedef SharePull = Future<String> Function({
  required String serverFilename,
  required String savePath,
  required void Function(int received, int total) onBytes,
  required TransferCancel cancel,
});

final sharePullProvider = Provider<SharePull>(
  (ref) =>
      ({
        required serverFilename,
        required savePath,
        required onBytes,
        required cancel,
      }) {
        final api = ref.read(apiClientProvider);
        if (api == null) throw const NetworkException('no server configured');
        return Transfer(api: api).pull(
          serverFilename: serverFilename,
          savePath: savePath,
          onBytes: onBytes,
          cancel: cancel,
        );
      },
);

final shareSendProvider = Provider<Future<void> Function(String path)>(
  (ref) =>
      (path) async => Share.shareXFiles([XFile(path)]),
);

/// A folder of its own, so a sweep never touches anything else in the
/// cache. A provider because `path_provider` does not work in tests.
final shareDirProvider = FutureProvider<String>(
  (ref) async => '${(await getTemporaryDirectory()).path}/share',
);

/// Is the app on screen? The share menu cannot open from the background.
final shareForegroundProvider = Provider<bool Function()>(
  (ref) =>
      () => switch (WidgetsBinding.instance.lifecycleState) {
        null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
        _ => false,
      },
);

final shareFlowProvider = NotifierProvider<ShareFlow, ShareJob?>(ShareFlow.new);

/// Pulls a clip that is only on the server, then opens the share menu.
class ShareFlow extends Notifier<ShareJob?> {
  TransferCancel? _cancel;
  AppLifecycleListener? _life;
  String? _ready;
  bool _noticed = false;

  /// Set by the sheet while it is open. A failure nobody can see is told
  /// by a notice instead, and the share is cleared for the next try.
  bool watched = false;

  @override
  ShareJob? build() {
    ref.onDispose(() => _life?.dispose());
    return null;
  }

  /// One share at a time: a second call while one runs does nothing, so a
  /// double tap pulls the clip once.
  Future<void> start(LibraryItem item) async {
    if (state != null) return;
    final filename = item.serverFilename;
    if (filename == null) throw const UnsafeFilenameException();
    final cancel = _cancel = TransferCancel();
    final url = item.canonicalUrl;
    state = ShareJob(url: url, title: item.title, total: item.sizeBytes ?? 0);
    notePullProgress(ref, url, 0);
    // Held while the copy runs, so leaving the app does not freeze it.
    final hold = ref.read(backgroundHoldProvider);
    unawaited(hold.set('share', true));
    final rate = TransferRate();
    final clock = Stopwatch()..start();
    var shownAt = const Duration(days: -1);
    try {
      final dir = await ref.read(shareDirProvider.future);
      await Directory(dir).create(recursive: true);
      await sweepShareFolder(dir);
      final name = buildLocalFilename(item.title, serverFilename: filename);
      // The pull may pick another name if this one is taken, so what is
      // shared is the path it returns.
      final path = await ref.read(sharePullProvider)(
        serverFilename: filename,
        savePath: '$dir/$name',
        cancel: cancel,
        onBytes: (received, total) {
          final at = clock.elapsed;
          final speed = rate.sample(received, at);
          // Many reports a second would rebuild the sheet for nothing.
          if (at - shownAt < const Duration(milliseconds: 200) &&
              received < total) {
            return;
          }
          shownAt = at;
          if (state?.phase != SharePhase.pulling) return;
          state = state!.copyWith(
            received: received,
            total: total,
            rate: speed,
          );
          if (total > 0) notePullProgress(ref, url, received / total);
        },
      );
      // Cleared before the share menu: it is awaited until it closes, and
      // the card read 100% all that time.
      notePullProgress(ref, url, null);
      await _deliver(path);
    } on CancelledException {
      _finish();
    } on Object catch (e) {
      if (state == null) return;
      unawaited(logError(ref.read(loggerProvider), e, tag: 'share'));
      if (watched && ref.read(shareForegroundProvider)()) {
        state = state!.copyWith(phase: SharePhase.failed, error: e);
      } else {
        await _notice(e);
        state = null;
      }
    } finally {
      notePullProgress(ref, url, null);
      _cancel = null;
      unawaited(hold.set('share', false));
    }
  }

  Future<void> _deliver(String path) async {
    if (ref.read(shareForegroundProvider)()) {
      _finish();
      await ref.read(shareSendProvider)(path);
      return;
    }
    // Away from the app: wait for the user to come back, and say so.
    _ready = path;
    state = state!.copyWith(phase: SharePhase.ready);
    _life = AppLifecycleListener(onResume: () => unawaited(sendReady()));
    await _notice(null);
  }

  /// Opens the share menu for a copy that finished while the app was away.
  Future<void> sendReady() async {
    final path = _ready;
    if (path == null) return;
    _finish();
    await ref.read(shareSendProvider)(path);
  }

  /// Stops the pull, or drops a finished copy nobody shared.
  void cancel() {
    final pulling = _cancel;
    if (pulling != null && !pulling.isCancelled) {
      pulling.cancel();
      return;
    }
    _finish();
  }

  /// Closes a failed share once its message has been read.
  void dismiss() => _finish();

  /// The sheet went away. A failure it showed is done with; any other phase
  /// goes on without it. Later, because the sheet is still being torn down.
  void sheetClosed() {
    watched = false;
    if (state?.phase == SharePhase.failed) unawaited(Future.microtask(_finish));
  }

  Future<void> _notice(Object? error) async {
    final job = state;
    if (job == null) return;
    final l10n = mtLocalizationsFor(ref.read(settingsProvider).localeCode);
    _noticed = true;
    await ref
        .read(notificationsProvider)
        .showResult(
          shareNotificationId,
          title: error == null ? l10n.shareReady : l10n.failed,
          body: job.title,
          channelName: l10n.activeDownloads,
          payload: job.url,
          isError: error != null,
        );
  }

  void _finish() {
    _stopWaiting();
    state = null;
  }

  void _stopWaiting() {
    _ready = null;
    _life?.dispose();
    _life = null;
    if (_noticed) {
      _noticed = false;
      unawaited(ref.read(notificationsProvider).cancel(shareNotificationId));
    }
  }
}
