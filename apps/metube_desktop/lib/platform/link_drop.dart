import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

/// The whole window as a drop target for links: a link dragged from a
/// browser, a selected text that holds links, or a text file of them. What
/// arrives is handed on as text, and the add dialog reads the links in it.
///
/// While something is dragged over, the window says it can be dropped.
class LinkDropArea extends StatefulWidget {
  const LinkDropArea({super.key, required this.onText, required this.child});

  final ValueChanged<String> onText;
  final Widget child;

  @override
  State<LinkDropArea> createState() => _LinkDropAreaState();
}

class _LinkDropAreaState extends State<LinkDropArea> {
  bool _over = false;

  Future<String> _read(DropItem item) {
    final done = Completer<String>();
    final reader = item.dataReader;
    void finish(String? value) {
      if (!done.isCompleted) done.complete(value ?? '');
    }

    void onError(Object _) => finish(null);
    if (reader == null) {
      finish(null);
    } else if (reader.canProvide(Formats.uri)) {
      reader.getValue<NamedUri>(
        Formats.uri,
        (value) => finish(value?.uri.toString()),
        onError: onError,
      );
    } else if (reader.canProvide(Formats.fileUri)) {
      reader.getValue<Uri>(
        Formats.fileUri,
        (value) => unawaited(_readFile(value).then(finish)),
        onError: onError,
      );
    } else if (reader.canProvide(Formats.plainText)) {
      reader.getValue<String>(Formats.plainText, finish, onError: onError);
    } else {
      finish(null);
    }
    return done.future;
  }

  /// A dropped file is read only when it is a small text file (a list of
  /// links) or a phone's backup or transcripts file, never a video someone
  /// meant to play.
  static Future<String> _readFile(Uri? uri) async {
    if (uri == null || !uri.isScheme('file')) return '';
    final file = File.fromUri(uri);
    final name = file.path.toLowerCase();
    final limit = name.endsWith('.txt')
        ? MTConstants.maxTextFileBytes
        : name.endsWith('.json')
        ? _maxBackupBytes
        : 0;
    if (limit == 0) return '';
    try {
      if (await file.length() > limit) return '';
      return await file.readAsString();
    } on Object {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return DropRegion(
      formats: const [Formats.uri, Formats.fileUri, Formats.plainText],
      hitTestBehavior: HitTestBehavior.translucent,
      onDropOver: (event) =>
          event.session.allowedOperations.contains(DropOperation.copy)
          ? DropOperation.copy
          : DropOperation.none,
      onDropEnter: (_) => setState(() => _over = true),
      onDropLeave: (_) => setState(() => _over = false),
      onPerformDrop: (event) async {
        final reads = [for (final item in event.session.items) _read(item)];
        unawaited(
          Future.wait(reads).then((texts) {
            final text = texts.where((t) => t.isNotEmpty).join('\n');
            if (text.isNotEmpty && mounted) widget.onText(text);
          }),
        );
      },
      child: Stack(
        children: [
          widget.child,
          if (_over)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: p.accentSoft.withValues(alpha: 0.85),
                  child: Center(
                    child: Text(
                      context.mtl.desktopDropLinks,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: p.accentInk),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A transcripts file of a large library runs to tens of megabytes.
  static const _maxBackupBytes = 64 * 1024 * 1024;
}
