import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import '../../shell/error_text.dart';
import '../library/platform_label.dart';
import 'add_options.dart';
import 'batch_dialog.dart';
import 'link_lines.dart';

/// Several links at once, one line each: the site, the link, and what will
/// happen to it, or once sent, how it is going. A line can be taken out
/// before sending; a playlist opens its own dialog; a failed one keeps its
/// reason and offers to try again.
class LinksView extends ConsumerWidget {
  const LinksView({
    super.key,
    required this.read,
    required this.choice,
    required this.tasks,
    required this.onRemove,
    required this.onRetry,
  });

  final ReadLinks read;
  final AddChoice choice;

  /// The links sent, by their task's id.
  final Map<String, String> tasks;
  final ValueChanged<LinkLine> onRemove;
  final void Function(String url, String taskId) onRetry;

  /// Sends every ready link, one after another as the engine's queue
  /// takes them, each with the one choice for all.
  static Map<String, String> submit(
    DownloadEngine engine,
    ReadLinks read,
    AddChoice choice,
  ) => {
    for (final url in read.ready)
      url: engine
          .submit(
            url,
            choice.qualityFor(url),
            isBatchMember: true,
            folder: choice.folderPath,
          )
          .id,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final engine = ref.watch(downloadEngineProvider);
    return StreamBuilder<DownloadTask>(
      stream: engine?.updates,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.desktopLinksFound(read.lines.length),
            style: text.labelMedium?.copyWith(color: p.ink2),
          ),
          if (read.dropped > 0)
            Padding(
              padding: const EdgeInsets.only(top: MTSpace.xxs),
              child: Text(
                l.desktopLinksDropped(read.dropped, MTConstants.maxLinksPerAdd),
                style: text.bodySmall?.copyWith(color: p.err),
              ),
            ),
          const SizedBox(height: MTSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _listHeight),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final line in read.lines)
                  _Line(
                    line: line,
                    task: switch (tasks[line.url]) {
                      final id? => engine?.taskById(id),
                      null => null,
                    },
                    sent: tasks.isNotEmpty,
                    onRemove: () => onRemove(line),
                    onRetry: engine == null
                        ? null
                        : () {
                            final task = engine.submit(
                              line.url,
                              choice.qualityFor(line.url),
                              isBatchMember: true,
                              folder: choice.folderPath,
                            );
                            onRetry(line.url, task.id);
                          },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const double _listHeight = 320;
}

class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.task,
    required this.sent,
    required this.onRemove,
    required this.onRetry,
  });

  final LinkLine line;
  final DownloadTask? task;
  final bool sent;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final failed = task?.phase == TaskPhase.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.xxs),
      child: Row(
        children: [
          SizedBox(
            width: _siteWidth,
            child: Text(
              platformLabel(l, line.platform),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: p.ink2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: text.bodySmall?.copyWith(
                    color: line.state == LinkState.ready ? p.ink : p.ink3,
                  ),
                ),
                switch (task) {
                  final task? => Text(
                    taskLine(l, task),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: failed ? p.err : p.ink3,
                    ),
                  ),
                  null => LinkStateLine(line: line),
                },
              ],
            ),
          ),
          if (line.state == LinkState.playlist)
            MTLinkButton(
              label: l.batchTitle,
              onPressed: () => unawaited(showBatchDialog(context, line.url)),
            )
          else if (failed && onRetry != null)
            MTLinkButton(label: l.retry, onPressed: onRetry)
          else if (!sent)
            MTShortcutTooltip(
              message: l.remove,
              child: IconButton(
                onPressed: onRemove,
                icon: MTIcon(
                  MTIcons.close,
                  size: MTSpace.md,
                  color: p.ink3,
                  semanticLabel: l.remove,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const double _siteWidth = 96;
}

/// How a sent link is going, in a word, or why it failed.
String taskLine(MTLocalizations l, DownloadTask task) => switch (task.phase) {
  TaskPhase.queued => l.queuedSection,
  TaskPhase.adding => l.addingToServer,
  TaskPhase.failed => switch (task.error) {
    final error? => errorText(l, error),
    null => l.failed,
  },
  TaskPhase.cancelled => l.cancel,
  TaskPhase.completed => l.completed,
  _ => l.onServerPhase,
};

/// What will happen to a link that has not been sent.
class LinkStateLine extends StatelessWidget {
  const LinkStateLine({super.key, required this.line});

  final LinkLine line;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final (label, color) = switch (line.state) {
      LinkState.ready => (l.desktopLinkReady, p.accentInk),
      LinkState.inLibrary => (l.desktopLinkInLibrary, p.ink3),
      LinkState.unsupported => (l.desktopLinkUnsupported, p.err),
      LinkState.duplicate => (l.desktopLinkDuplicate, p.ink3),
      LinkState.playlist => (l.desktopLinkPlaylist, p.ink2),
    };
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}
