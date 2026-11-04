import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/clip_handover.dart';
import '../../data/file_copy.dart';
import '../../data/folders_data.dart';
import '../../data/local_copies.dart';

/// Copies [item]'s file to the clipboard, to be pasted into a chat, a mail
/// or a folder: the computer's own share, as the phone's share sheet is
/// the phone's.
///
/// A clip only on the server is saved into the download folder first, with
/// its progress and its Cancel in Downloads, and goes on the clipboard when
/// it is there. It is never held in a hidden temporary file: a paste may
/// come minutes later, and a file deleted before then pastes nothing.
///
/// Everything is read through the provider container, not a widget's ref:
/// the pull may end long after the menu or the row that asked has gone.
Future<void> copyFileOf(BuildContext context, LibraryItem item) async {
  final l = context.mtl;
  // The root's context outlives the menu or the row that asked.
  final notices = Navigator.of(context, rootNavigator: true).context;
  final container = ProviderScope.containerOf(context, listen: false);
  void say(String message, [MTNoticeKind kind = MTNoticeKind.info]) {
    if (notices.mounted) showMTNotice(notices, message: message, kind: kind);
  }

  void paste(String path) {
    if (!container.read(filesToClipboardProvider)([path])) {
      say(l.desktopCopyFileFailed, MTNoticeKind.failed);
      return;
    }
    final name = path.substring(path.lastIndexOf(r'\') + 1);
    say(
      l.desktopFileReadyToPaste(name, mtFormatSize(fileLength(path) ?? 0)),
      MTNoticeKind.done,
    );
  }

  final folder = await container.read(downloadFolderProvider.future);
  if (folder != null &&
      pullUnderWay(
            container.read(localCopiesProvider),
            item.canonicalUrl,
            folder,
          ) !=
          null) {
    say(l.desktopCopyFilePreparing);
    return;
  }
  final plan = planFileCopy(
    item,
    localFile: container.read(clipHandoverProvider).localFile(item),
    folder: folder,
    lengthOf: fileLength,
    freeBytes: folder == null
        ? null
        : container.read(freeBytesProvider)(folder),
  );
  switch (plan) {
    case CopyNow(:final path):
      paste(path);
    case NothingToCopy():
      say(l.desktopCopyFileFailed, MTNoticeKind.failed);
    case NoSpace(:final needed, :final free):
      say(
        l.desktopCopyFileNoSpace(mtFormatSize(needed), mtFormatSize(free)),
        MTNoticeKind.failed,
      );
    case PullFirst(:final source, folder: final into, :final large):
      if (large) {
        if (!notices.mounted) return;
        final sure = await showMTConfirm(
          notices,
          title: l.desktopCopyFileLarge,
          message: l.desktopCopyFileLargeMessage(
            mtFormatSize(item.sizeBytes ?? 0),
          ),
          confirmLabel: l.desktopCopyFile,
          cancelLabel: l.cancel,
        );
        if (!sure) return;
      }
      final copies = container.read(localCopiesProvider.notifier);
      if (!await copies.download(source, into: into)) return;
      final id = pullUnderWay(
        container.read(localCopiesProvider),
        item.canonicalUrl,
        into,
      )?.id;
      if (id == null) return;
      say(l.desktopCopyFilePreparing);
      late final ProviderSubscription<List<LocalCopy>> watch;
      watch = container.listen(localCopiesProvider, (_, next) {
        final copy = next.where((c) => c.id == id).firstOrNull;
        if (copy != null && copy.isActive) return;
        watch.close();
        switch (copy) {
          case LocalCopy(phase: CopyPhase.done, :final path?):
            paste(path);
          case LocalCopy(phase: CopyPhase.failed):
            say(l.desktopCopyFileFailed, MTNoticeKind.failed);
          // Cancelled from Downloads, or taken off its list: nothing to say.
          case _:
        }
      });
  }
}
