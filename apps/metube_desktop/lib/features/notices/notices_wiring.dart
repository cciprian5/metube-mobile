import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/choices_data.dart';
import '../../data/downloads_data.dart';
import '../../data/folders_data.dart';
import '../../data/library_data.dart';
import '../../data/local_copies.dart';
import '../../data/notices.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/error_text.dart';

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

  /// What this app sent in this run: the engine announces those.
  final _mine = <String>{};

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
      if (task.canonicalUrl case final url?) _mine.add(url);
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
    for (final copy in ended) {
      unawaited(_show(_forCopy(copy)));
    }
  }

  Future<void> _onLibrary(List<LibraryItem> items) async {
    // Checked even when the notice is off, so turning it on later does not
    // announce everything that came in the meantime.
    final arrived = await ref.read(arrivalsProvider).check(items, mine: _mine);
    if (arrived.isEmpty || !mounted || !ref.read(notifyArrivalsProvider)) {
      return;
    }
    final l = context.mtl;
    // One notice for the batch, as on the phone.
    String name(LibraryItem item) =>
        item.title.trim().isEmpty ? item.canonicalUrl : item.title.trim();
    await _show(
      EmberNotice(
        title: l.newFromSubscriptions(arrived.length),
        body: arrived.take(3).map(name).join(' · '),
        onClick: () => unawaited(_open(arrived.first.canonicalUrl)),
      ),
    );
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
  Widget build(BuildContext context) => widget.child;
}
