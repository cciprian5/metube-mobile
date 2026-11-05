import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:mt_core/mt_core.dart' show TransferCancel;
import 'package:mt_media/library.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../data/clip_handover.dart';

/// Carried by every drag that starts in this window, so the window's own
/// drop target lets it pass instead of offering to add it as a link.
const emberDragMark = 'metube-ember-clip';

/// A clip dragged to Explorer or the desktop becomes its file. A copy on
/// this computer is handed over as a file; a clip only on the server is a
/// file Explorer asks for when it is dropped, pulled then, under Explorer's
/// own progress window and its Cancel.
class ClipDragSource extends StatelessWidget {
  const ClipDragSource({
    super.key,
    required this.item,
    required this.handover,
    required this.child,
  });

  final LibraryItem item;
  final ClipHandover handover;
  final Widget child;

  Future<DragItem?> _provide(DragItemRequest _) async {
    final name = handover.nameOf(item);
    if (name == null) return null;
    final drag = DragItem(suggestedName: name, localData: emberDragMark);
    if (handover.localFile(item) case final path?) {
      drag.add(Formats.fileUri(Uri.file(path, windows: true)));
    } else {
      drag.addVirtualFile(
        format: _formatOf(name),
        // The package does not export these callbacks' types, so the work
        // is written where they are inferred.
        provider: (sinkFor, progress) => unawaited(() async {
          final cancel = TransferCancel();
          progress.onCancel.addListener(cancel.cancel);
          File? pulled;
          EventSink<Object?>? sink;
          try {
            // The pull is the wait; copying out of it after is quick.
            pulled = await handover.pull(
              item,
              cancel: cancel,
              onProgress: (p) => progress.updateProgress(p * _pullShare),
            );
            final size = await pulled.length();
            final out = sink = sinkFor(fileSize: size);
            var written = 0;
            await for (final chunk in pulled.openRead()) {
              // Cancelled in Explorer: the sink is already closed there.
              if (cancel.isCancelled) return;
              out.add(chunk is Uint8List ? chunk : Uint8List.fromList(chunk));
              written += chunk.length;
              progress.updateProgress(
                _pullShare +
                    (1 - _pullShare) * written / (size == 0 ? 1 : size),
              );
            }
            out.close();
          } on Object catch (e) {
            if (!cancel.isCancelled) (sink ?? sinkFor(fileSize: 0)).addError(e);
          } finally {
            progress.onCancel.removeListener(cancel.cancel);
            if (pulled != null) unawaited(handover.discard(pulled));
          }
        }()),
      );
    }
    return drag;
  }

  /// Explorer goes by the name; the format only has to be a file one.
  static FileFormat _formatOf(String name) =>
      switch (name.substring(name.lastIndexOf('.') + 1).toLowerCase()) {
        'webm' => Formats.webm,
        'mkv' => Formats.mkv,
        'mov' => Formats.mov,
        'm4a' => Formats.m4a,
        'mp3' => Formats.mp3,
        'opus' => Formats.opus,
        'ogg' => Formats.ogg,
        'flac' => Formats.flac,
        'wav' => Formats.wav,
        'aac' => Formats.aac,
        _ => Formats.mp4,
      };

  /// The share of Explorer's progress bar the pull takes.
  static const _pullShare = 0.9;

  @override
  Widget build(BuildContext context) => DragItemWidget(
    allowedOperations: () => const [DropOperation.copy],
    dragItemProvider: _provide,
    child: DraggableWidget(child: child),
  );
}
