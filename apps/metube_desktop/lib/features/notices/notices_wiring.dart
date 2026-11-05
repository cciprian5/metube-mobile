import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/channels_data.dart';
import '../../data/choices_data.dart';
import '../../data/downloads_data.dart';
import '../../data/file_copy.dart';
import '../../data/folders_data.dart';
import '../../data/library_data.dart';
import '../../data/local_copies.dart';
import '../../data/notices.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/error_text.dart';
import '../../shell/hints_wiring.dart';

/// **Windows notifications** for what ends while the window is away: a
/// download done or failed on the server, a copy saved to this computer,
/// and what a followed channel brought by itself. In front, the downloads
/// panel says it already, so nothing is shown.
class NoticesWiring extends ConsumerStatefulWidget {
  const NoticesWiring({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NoticesWiring> createState() => _NoticesWiringState();
}

class _NoticesWiringState extends ConsumerState<NoticesWiring> {
  final _phases = <String, TaskPhase>{};
  final _copyPhases = <String, CopyPhase>{};

  /// What this app sent: the engine announces those. It reaches back across
  /// runs, through [_sends], for what finished while the app was closed.
  final _mine = <String>{};
  var _sendsRead = false;

  late final _sends = UnfinishedSends(
    store: ref.read(keyValueStoreProvider),
    mutex: ref.read(prefsMutexProvider),
    key: 'ember_unfinished_sends',
  );

  /// What each subscription's checks queued: only those clips are news.
  late final _checks = SubscriptionChecks(
    store: ref.read(keyValueStoreProvider),
    mutex: ref.read(prefsMutexProvider),
    key: 'ember_subscription_checks',
  );

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      engineTasksProvider,
      (_, next) => _onTasks(next.valueOrNull ?? const []),
      fireImmediately: true,
    );
    ref.listenManual(
      localCopiesProvider,
      (_, next) => _onCopies(next),
      fireImmediately: true,
    );
    ref.listenManual(libraryItemsProvider, (_, next) {
      if (next.valueOrNull case final items?) unawaited(_onLibrary(items));
    }, fireImmediately: true);
  }

  void _onTasks(List<DownloadTask> tasks) {
    for (final task in tasks) {
      if (task.canonicalUrl case final url?) {
        if (_mine.add(url)) unawaited(_sends.note(url, finished: false));
      }
    }
    final ended = newlyEnded(_phases, tasks);
    _phases
      ..clear()
      ..addAll({for (final task in tasks) task.id: task.phase});
    for (final task in ended) {
      unawaited(_show(_forTask(task)));
    }
  }

  void _onCopies(List<LocalCopy> copies) {
    final ended = newlyEndedCopies(_copyPhases, copies);
    _copyPhases
      ..clear()
      ..addAll({for (final copy in copies) copy.id: copy.phase});
    final forPaste = ref.read(pastePullsProvider);
    for (final copy in ended) {
      // Its own "ready to paste" says what happened.
      if (forPaste.contains(copy.id)) continue;
      unawaited(_show(_forCopy(copy)));
      // A file the user downloaded, not an offline copy the app keeps.
      if (copy.phase == CopyPhase.done &&
          copy.kind == CopyKind.download &&
          ref.read(revealAfterDownloadProvider)) {
        if (copy.path case final path?) {
          unawaited(ref.read(desktopFoldersProvider).reveal(path));
        }
      }
    }
  }

  Future<void> _onLibrary(List<LibraryItem> items) async {
    if (!_sendsRead) {
      _sendsRead = true;
      _mine.addAll(await _sends.all());
      // Where counting starts for this run.
      if (ref.read(notifyArrivalsProvider)) {
        await _checks.observe(await _following());
      }
    }
    // Checked even when the notice is off, so turning it on later does not
    // announce everything that came in the meantime.
    final arrived = await ref.read(arrivalsProvider).check(items, mine: _mine);
    await _sends.settle([
      for (final item in items)
        if (item.onServer && item.serverFilename != null) item.canonicalUrl,
    ]);
    if (arrived.isEmpty || !mounted || !ref.read(notifyArrivalsProvider)) {
      return;
    }
    // **Read afresh**: each subscription's count and last check tell a clip
    // it queued from one the phone or the web page sent, which is nobody's
    // news here even from a followed channel (owner's report, 2026-11-05).
    ref.invalidate(channelsProvider);
    final following = await _following();
    final sorted = await sortArrivals<LibraryItem>(
      arrived,
      urlOf: (item) => item.canonicalUrl,
      uploaderOf: (item) => item.uploader,
      following: following,
      author: ref.read(arrivalAuthorProvider),
    );
    await _checks.observe(following);
    final worth = await _checks.fromChecks([
      ...sorted.followed,
      ...sorted.unknown,
    ], createdOf: (item) => item.timestamp);
    if (worth.isEmpty || !mounted) return;
    final l = context.mtl;
    // One notice for the batch, as on the phone.
    String name(LibraryItem item) =>
        item.title.trim().isEmpty ? item.canonicalUrl : item.title.trim();
    await _show(
      EmberNotice(
        title: l.newFromSubscriptions(worth.length),
        body: worth.take(3).map(name).join(' · '),
        onClick: () => unawaited(_open(worth.first.canonicalUrl)),
      ),
    );
  }

  /// The channels followed. No list at all is asked for twice before it
  /// counts as none, since a failed request and an old server read alike.
  Future<List<ChannelSubscription>> _following() async {
    try {
      var state = await ref.read(channelsProvider.future);
      if (!state.supported) {
        ref.invalidate(channelsProvider);
        state = await ref.read(channelsProvider.future);
      }
      return state.subscriptions ?? const [];
    } on Object {
      return const [];
    }
  }

  EmberNotice? _forTask(DownloadTask task) {
    if (!mounted) return null;
    final l = context.mtl;
    final name = task.title ?? task.inputUrl;
    final url = task.canonicalUrl;
    if (task.phase == TaskPhase.failed) {
      return EmberNotice(
        title: l.downloadFailed,
        // The reason in the notice itself: "failed" alone leaves a dropped
        // network, a refused link and a wrong password to guesswork.
        body:
            '$name · ${task.error == null ? l.failed : errorText(l, task.error!)}',
      );
    }
    return EmberNotice(
      title: l.downloadComplete,
      body: name,
      actions: [
        if (url != null)
          (label: l.play, onPressed: () => unawaited(_play(url))),
      ],
      onClick: url == null ? null : () => unawaited(_open(url)),
    );
  }

  EmberNotice? _forCopy(LocalCopy copy) {
    if (!mounted) return null;
    final l = context.mtl;
    if (copy.phase == CopyPhase.failed) {
      return EmberNotice(
        title: l.downloadFailed,
        body:
            '${copy.title} · ${copy.error == null ? l.failed : errorText(l, copy.error!)}',
      );
    }
    final folders = ref.read(desktopFoldersProvider);
    return EmberNotice(
      title: l.desktopNoticeSaved,
      body: copy.title,
      actions: [
        // The user's own download is theirs to open; the app forgot it.
        if (copy.kind == CopyKind.offline)
          (label: l.play, onPressed: () => unawaited(_play(copy.canonicalUrl))),
        (
          label: l.desktopShowInFolder,
          onPressed: () => unawaited(folders.open(copy.folder)),
        ),
      ],
      onClick: () => unawaited(_open(copy.canonicalUrl)),
    );
  }

  Future<void> _show(EmberNotice? notice) async {
    if (notice == null) return;
    if (await ref.read(windowInFrontProvider)()) return;
    await ref.read(noticePortProvider).show(notice);
  }

  Future<void> _open(String canonicalUrl) async {
    await ref.read(bringWindowBackProvider)();
    if (mounted) GoRouter.of(context).go(EmberRoutes.item(canonicalUrl));
  }

  Future<void> _play(String canonicalUrl) async {
    await _open(canonicalUrl);
    final items = ref.read(libraryItemsProvider).valueOrNull ?? const [];
    final item = items.where((i) => i.canonicalUrl == canonicalUrl).firstOrNull;
    if (item == null) return;
    await ref.read(playerProvider).playItems([toPlaylistItem(item)]);
  }

  @override
  // The app's two tips come from here too.
  Widget build(BuildContext context) => HintsWiring(child: widget.child);
}
