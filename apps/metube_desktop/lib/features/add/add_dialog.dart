import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import '../../data/library_data.dart';
import '../../shell/shell_metrics.dart';
import '../library/platform_label.dart';
import 'add_options.dart';
import 'batch_dialog.dart';
import 'link_lines.dart';
import 'link_preview_card.dart';
import 'links_view.dart';

/// Opens the add dialog with [text] in its field: a link, or a text that
/// holds several, from the clipboard, a drop or the button.
Future<void> openAddDialog(BuildContext context, {String text = ''}) =>
    showDialog<void>(context: context, builder: (_) => _AddDialog(text));

class _AddDialog extends ConsumerStatefulWidget {
  const _AddDialog(this.text);

  final String text;

  @override
  ConsumerState<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends ConsumerState<_AddDialog> {
  late final _field = TextEditingController(text: widget.text.trim());
  AddChoice _choice = const AddChoice();
  final _removed = <String>{};

  /// The links sent, each with its task, so its line follows it.
  Map<String, String> _tasks = const {};

  bool get _sent => _tasks.isNotEmpty;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  ReadLinks _read() {
    final library = [
      for (final item
          in ref.read(libraryItemsProvider).valueOrNull ?? <LibraryItem>[])
        item.canonicalUrl,
    ];
    final read = readLinks(_field.text, library);
    return ReadLinks([
      for (final line in read.lines)
        if (!_removed.contains(line.url)) line,
    ], dropped: read.dropped);
  }

  void _notice(String message, {MTNoticeKind kind = MTNoticeKind.info}) {
    if (mounted) showMTNotice(context, message: message, kind: kind);
  }

  /// One link: a playlist goes to its own dialog, anything else is added.
  Future<void> _submitOne(String url) async {
    final l = context.mtl;
    final engine = ref.read(downloadEngineProvider);
    if (engine == null) return _notice(l.noServerTitle);
    final navigator = Navigator.of(context);
    final resolved = await ShortLinkResolver().resolveForRouting(url);
    if (!mounted) return;
    if (PlaylistDetector.isPlaylist(resolved)) {
      navigator.pop();
      return showBatchDialog(navigator.context, resolved);
    }
    engine.submit(
      url,
      _choice.qualityFor(resolved),
      folder: _choice.folderPath,
    );
    navigator.pop();
    _notice(l.downloadStarted, kind: MTNoticeKind.done);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final read = _read();
    final lines = read.lines;
    final many = lines.length > 1 || read.dropped > 0;
    final single = lines.length == 1 ? lines.single : null;
    final url = single?.url;
    final youtube =
        lines.isNotEmpty && lines.every((line) => line.platform.isYouTube);
    final canSubmit = many ? read.ready.isNotEmpty && !_sent : url != null;

    return AlertDialog(
      title: Text(l.addUrl),
      content: SizedBox(
        width: many ? EmberShellSize.wideDialog : EmberShellSize.addDialog,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _field,
                autofocus: true,
                minLines: 1,
                maxLines: many ? 4 : 2,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                onChanged: (_) => setState(() => _tasks = const {}),
                decoration: InputDecoration(
                  hintText: l.pasteUrlHint,
                  hintTextDirection: TextDirection.ltr,
                  suffixText: url == null
                      ? null
                      : platformLabel(l, MediaPlatform.detect(url)),
                ),
              ),
              const SizedBox(height: MTSpace.md),
              if (many)
                LinksView(
                  read: read,
                  choice: _choice,
                  tasks: _tasks,
                  onRemove: (line) => setState(() => _removed.add(line.url)),
                  onRetry: (url, id) =>
                      setState(() => _tasks = {..._tasks, url: id}),
                )
              else if (single case final line?)
                switch (line.state) {
                  LinkState.playlist => LinkStateLine(line: line),
                  _ => LinkPreviewCard(url: line.url),
                },
              const SizedBox(height: MTSpace.md),
              if (single?.state != LinkState.playlist)
                AddOptions(
                  choice: _choice,
                  youtube: youtube,
                  offerTranscript:
                      !many &&
                      url != null &&
                      UrlKit.youtubeVideoId(url) != null,
                  onChanged: (choice) => setState(() => _choice = choice),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_sent ? l.done : l.cancel),
        ),
        FilledButton(
          onPressed: !canSubmit
              ? null
              : () {
                  if (many) {
                    final engine = ref.read(downloadEngineProvider);
                    if (engine == null) return _notice(l.noServerTitle);
                    setState(
                      () => _tasks = LinksView.submit(engine, read, _choice),
                    );
                  } else {
                    unawaited(_submitOne(url!));
                  }
                },
          child: Text(
            many
                ? l.desktopAddLinks(read.ready.length)
                : single?.state == LinkState.playlist
                ? l.batchTitle
                : l.startDownload,
          ),
        ),
      ],
    );
  }
}
