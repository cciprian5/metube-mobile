import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import '../../data/library_data.dart';
import '../../data/local_copies.dart';
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

  /// The folder picked for "then download it to this computer", or null
  /// for the download folder.
  String? _pullInto;

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

  /// The folder for "then download it to this computer", **asked now**
  /// when the user wants to be asked: the server may take minutes, and a
  /// dialog then would come from nowhere. False when it was closed.
  Future<bool> _askPullFolder() async {
    if (!_choice.pullAfter) return true;
    final chosen = await ref
        .read(localCopiesProvider.notifier)
        .chooseDownloadFolder();
    if (chosen.asked && chosen.into == null) return false;
    _pullInto = chosen.asked ? chosen.into : null;
    return true;
  }

  void _markPull(Iterable<String> taskIds) {
    if (!_choice.pullAfter) return;
    final pulls = ref.read(pullAfterProvider);
    for (final id in taskIds) {
      pulls[id] = _pullInto;
    }
  }

  /// Several links, sent together with the one choice for all.
  Future<void> _submitMany(ReadLinks read) async {
    final engine = ref.read(downloadEngineProvider);
    if (engine == null) return _notice(context.mtl.noServerTitle);
    if (!await _askPullFolder() || !mounted) return;
    setState(() => _tasks = LinksView.submit(engine, read, _choice));
    _markPull(_tasks.values);
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
    if (!await _askPullFolder() || !mounted) return;
    final task = engine.submit(
      url,
      _choice.qualityFor(resolved),
      folder: _choice.folderPath,
    );
    _markPull([task.id]);
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
              // Named for a screen reader even once filled, when its hint
              // is gone and only the link would be read.
              Semantics(
                label: l.addUrl,
                child: TextField(
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
                    // A widget, not suffixText: the link reads left to right
                    // inside a right-to-left dialog, and the plain suffix sat
                    // flush against its first letter ("YouTubehttps://…").
                    suffix: url == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: MTSpace.sm,
                            ),
                            child: Text(
                              platformLabel(l, MediaPlatform.detect(url)),
                              key: const ValueKey('addLinkSite'),
                              style: Theme.of(context)
                                  .inputDecorationTheme
                                  .hintStyle,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: MTSpace.md),
              if (many)
                LinksView(
                  read: read,
                  choice: _choice,
                  tasks: _tasks,
                  onRemove: (line) => setState(() => _removed.add(line.url)),
                  onRetry: (url, id) {
                    _markPull([id]);
                    setState(() => _tasks = {..._tasks, url: id});
                  },
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
                    unawaited(_submitMany(read));
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
