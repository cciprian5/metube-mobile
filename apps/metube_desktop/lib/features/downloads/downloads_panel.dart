import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import '../../data/folders_data.dart';
import '../../data/local_copies.dart';
import '../../shell/section_header.dart';
import '../add/links_view.dart';

/// The downloads, opened from the button above the content and drawn at
/// its corner: what the server is fetching, what waits its turn, what is
/// coming to this computer, and what failed, each with its own action.
Future<void> showDownloadsPanel(BuildContext context) => showGeneralDialog(
  context: context,
  barrierDismissible: true,
  barrierLabel: context.mtl.desktopDownloads,
  barrierColor: Colors.transparent,
  transitionDuration: MTMotion.tap,
  transitionBuilder: (_, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
  pageBuilder: (context, _, _) => const DownloadsPanel(),
);

class DownloadsPanel extends ConsumerWidget {
  const DownloadsPanel({super.key});

  static const double width = 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final engine = ref.watch(downloadEngineProvider);
    final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
    final copies = ref.watch(localCopiesProvider);
    final working = [
      for (final t in tasks)
        if (!t.isFinished && t.phase != TaskPhase.queued) t,
    ];
    final waiting = [
      for (final t in tasks)
        if (t.phase == TaskPhase.queued) t,
    ];
    final failed = [
      for (final t in tasks)
        if (t.phase == TaskPhase.failed) t,
    ];
    // Only lines the panel shows: a clip the server finished has no line
    // here, so it never offers to hide what cannot be seen.
    final finished = copies.any((c) => !c.isActive);
    final empty =
        working.isEmpty && waiting.isEmpty && failed.isEmpty && copies.isEmpty;

    // Hides finished lines from this panel; nothing is deleted, here or on
    // the server.
    void clearFinished() {
      ref.read(localCopiesProvider.notifier).clearFinished();
      for (final t in tasks) {
        if (t.isFinished && t.phase != TaskPhase.failed) engine?.forget(t.id);
      }
    }

    return SafeArea(
      child: Align(
        alignment: AlignmentDirectional.topEnd,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            top: MTSpace.xxl + MTSpace.xl,
            end: MTSpace.xl,
            bottom: MTSpace.xl,
            start: MTSpace.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: width),
            child: Material(
              color: p.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MTCorners.desktop.card),
                side: BorderSide(
                  color: p.line2,
                  width: MTThemeX.of(context).hairline,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(MTSpace.md),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.desktopDownloads,
                          style: text.titleMedium,
                        ),
                      ),
                      if (finished)
                        MTLinkButton(
                          label: l.desktopClearFinished,
                          onPressed: clearFinished,
                        ),
                    ],
                  ),
                  if (empty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: MTSpace.lg),
                      child: Text(
                        l.desktopDownloadsEmpty,
                        style: text.bodyMedium?.copyWith(color: p.ink2),
                      ),
                    ),
                  if (working.isNotEmpty) ...[
                    EmberSectionHeader(title: l.onServerPhase),
                    for (final t in working)
                      _TaskLine(task: t, onCancel: () => engine?.cancel(t.id)),
                  ],
                  if (waiting.isNotEmpty) ...[
                    EmberSectionHeader(title: l.queuedSection),
                    for (final t in waiting)
                      _TaskLine(task: t, onCancel: () => engine?.cancel(t.id)),
                  ],
                  if (copies.isNotEmpty) ...[
                    EmberSectionHeader(title: l.desktopToThisComputer),
                    for (final c in copies) _CopyLine(copy: c),
                  ],
                  if (failed.isNotEmpty) ...[
                    EmberSectionHeader(title: l.needsAttention),
                    for (final t in failed)
                      _TaskLine(
                        task: t,
                        onCancel: () => engine?.forget(t.id),
                        onRetry: engine == null
                            ? null
                            : () {
                                engine.submit(
                                  t.effectiveUrl,
                                  t.quality,
                                  folder: t.folder,
                                );
                                engine.forget(t.id);
                              },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A clip the server is fetching, waiting for, or failed.
class _TaskLine extends StatelessWidget {
  const _TaskLine({required this.task, required this.onCancel, this.onRetry});

  final DownloadTask task;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = task.phase == TaskPhase.failed;
    return PanelLine(
      title: task.title ?? task.effectiveUrl,
      status: taskLine(context.mtl, task),
      error: failed,
      // Waiting is not working: only a clip the server is on moves.
      progress: switch (task.phase) {
        TaskPhase.polling when task.hasKnownProgress => task.progress,
        TaskPhase.queued || TaskPhase.failed => null,
        _ => -1,
      },
      actions: [
        if (onRetry case final retry?)
          MTLinkButton(label: context.mtl.retry, onPressed: retry),
      ],
      onClose: onCancel,
    );
  }
}

/// A copy coming to this computer, or come.
class _CopyLine extends ConsumerWidget {
  const _CopyLine({required this.copy});

  final LocalCopy copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final copies = ref.read(localCopiesProvider.notifier);
    final percent = (copy.progress * 100).round();
    final status = switch (copy.phase) {
      CopyPhase.queued => l.desktopCopyQueued,
      CopyPhase.pulling when copy.kind == CopyKind.offline =>
        l.desktopSavingOffline(percent),
      CopyPhase.pulling => l.desktopDownloading(percent),
      CopyPhase.done when copy.kind == CopyKind.offline => l.madeOffline,
      CopyPhase.done => l.desktopSavedIn(copy.folder),
      CopyPhase.failed => l.failed,
      CopyPhase.cancelled => l.desktopCopyCancelled,
    };
    return PanelLine(
      title: copy.title,
      status: status,
      error: copy.phase == CopyPhase.failed,
      progress: switch (copy.phase) {
        CopyPhase.pulling => copy.progress,
        _ => null,
      },
      actions: [
        if (copy.phase == CopyPhase.failed || copy.phase == CopyPhase.cancelled)
          MTLinkButton(label: l.retry, onPressed: () => copies.retry(copy.id)),
        if (copy.phase == CopyPhase.done)
          if (copy.path case final path?)
            MTLinkButton(
              label: l.desktopShowInFolder,
              onPressed: () =>
                  unawaited(ref.read(desktopFoldersProvider).reveal(path)),
            ),
      ],
      onClose: copy.isActive ? () => copies.cancel(copy.id) : null,
    );
  }
}

/// One line of the panel: the title, what is happening to it, a thin bar
/// while it moves, and its actions.
class PanelLine extends StatelessWidget {
  const PanelLine({
    super.key,
    required this.title,
    required this.status,
    this.error = false,
    this.progress,
    this.actions = const [],
    this.onClose,
  });

  final String title;
  final String status;
  final bool error;

  /// 0 to 1; a negative value moves without a known end; null shows none.
  final double? progress;
  final List<Widget> actions;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l = context.mtl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mtName(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: error ? p.err : p.ink3,
                  ),
                ),
                if (progress case final value?)
                  Padding(
                    padding: const EdgeInsets.only(top: MTSpace.xxs),
                    child: LinearProgressIndicator(
                      value: value < 0 ? null : value,
                      minHeight: 3,
                      color: p.accent,
                      backgroundColor: p.line,
                    ),
                  ),
                // Under the text, where a long label wraps instead of
                // pushing the line past the panel at large text sizes.
                if (actions.isNotEmpty)
                  Wrap(spacing: MTSpace.xs, children: actions),
              ],
            ),
          ),
          if (onClose case final close?)
            MTShortcutTooltip(
              message: l.cancel,
              child: IconButton(
                onPressed: close,
                icon: MTIcon(
                  MTIcons.close,
                  size: MTSpace.md,
                  color: p.ink3,
                  semanticLabel: l.cancel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
