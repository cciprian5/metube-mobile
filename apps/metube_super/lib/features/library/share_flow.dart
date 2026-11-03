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
import '../home/download_watcher.dart' show notificationsProvider;
import '../shared/error_report.dart';
import 'library_actions.dart';

/// The notice that a copy finished, or failed, while the app was away.
const shareNotificationId = 770002;

/// A clip this large asks before it downloads: on mobile data one stray
/// tap would otherwise cost the whole file.
const shareConfirmBytes = 500 * 1024 * 1024;

/// How long a shared copy stays. The share menu returns before the
/// receiving app has finished reading the file, so deleting it at once
/// broke the share in apps that read it late.
const shareKeep = Duration(hours: 1);

enum SharePhase { pulling, ready, failed }

/// The share in flight, as the sheet shows it.
class ShareJob {
  const ShareJob({
    required this.url,
    required this.title,
    this.received = 0,
    this.total = 0,
    this.rate,
    this.phase = SharePhase.pulling,
    this.error,
  });

  final String url;
  final String title;
  final int received;

  /// Zero until the server says, unless the library already knew the size.
  final int total;

  /// Bytes a second, smoothed; null until there is enough to measure.
  final double? rate;
  final SharePhase phase;
  final Object? error;

  double? get progress =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;

  ShareJob copyWith({
    int? received,
    int? total,
    double? rate,
    SharePhase? phase,
    Object? error,
  }) => ShareJob(
    url: url,
    title: title,
    received: received ?? this.received,
    total: total ?? this.total,
    rate: rate ?? this.rate,
    phase: phase ?? this.phase,
    error: error ?? this.error,
  );
}

/// A smoothed speed. A raw reading per callback jumps around too much to
/// read, so each sample a half second apart moves it a third of the way.
class TransferRate {
  static const _every = Duration(milliseconds: 500);

  Duration? _at;
  int _received = 0;
  double? value;

  double? sample(int received, Duration at) {
    final last = _at;
    if (last == null) {
      _at = at;
      _received = received;
      return value;
    }
    final gap = at - last;
    if (gap < _every) return value;
    final now = (received - _received) * 1000 / gap.inMilliseconds;
    value = value == null ? now : value! + (now - value!) / 3;
    _at = at;
    _received = received;
    return value;
  }
}

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

/// Deletes copies kept past [shareKeep], and partial files a killed pull
/// left behind. Run at startup and before each share, so the folder never
/// holds more than the last hour's shares.
Future<int> sweepShareFolder(
  String path, {
  Duration olderThan = shareKeep,
}) async {
  final cutoff = DateTime.now().subtract(olderThan);
  var removed = 0;
  try {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        if ((await entity.stat()).modified.isAfter(cutoff)) continue;
        await entity.delete();
        removed++;
      } on FileSystemException {
        // Still open in the receiving app; the next sweep takes it.
      }
    }
  } on FileSystemException {
    // No cache folder to read; nothing to sweep.
  }
  return removed;
}
