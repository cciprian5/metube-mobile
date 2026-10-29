import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/local_copies.dart';

// The clip page's two copies, an **offline copy** the app keeps and plays
// and **"Download…"**, a file of the user's own, both leave the server's
// copy where it is. Their buttons are in clip_action_row.dart and the
// clip's menu; the work behind them is here.

/// Starts an offline copy, or says the folder for it cannot be used.
Future<void> makeOfflineCopy(
  BuildContext context,
  WidgetRef ref,
  CopySource source,
) async {
  final started = await ref
      .read(localCopiesProvider.notifier)
      .makeOffline(source);
  if (!started && context.mounted) {
    showMTNotice(context, message: context.mtl.desktopFolderUnavailable);
  }
}

/// Saves a file of the user's own and says where.
Future<void> downloadCopy(
  BuildContext context,
  WidgetRef ref,
  CopySource source,
) async {
  final copies = ref.read(localCopiesProvider.notifier);
  if (!await copies.download(source) || !context.mounted) return;
  final folder = ref.read(localCopiesProvider).last.folder;
  showMTNotice(context, message: context.mtl.desktopSavingTo(folder));
}

/// Deletes the offline copy; the server keeps its own.
Future<void> removeOfflineCopy(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item,
) async {
  await ref.read(localCopiesProvider.notifier).removeLocalCopy(item);
  if (context.mounted) {
    showMTNotice(context, message: context.mtl.desktopLocalCopyRemoved);
  }
}
