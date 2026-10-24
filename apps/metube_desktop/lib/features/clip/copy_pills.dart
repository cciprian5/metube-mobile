import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/local_copies.dart';
import '../../shell/pill.dart';

/// The clip page's two copy actions (07 §3‑b): an **offline copy** the app
/// keeps and plays, and **"Download…"**, a file of the user's own. Both
/// leave the server's copy where it is.
List<Widget> copyPills(BuildContext context, WidgetRef ref, LibraryItem item) {
  final l = context.mtl;
  final copies = ref.watch(localCopiesProvider);
  final source = copySourceOf(item);
  final pulling = copies
      .where(
        (c) =>
            c.canonicalUrl == item.canonicalUrl &&
            c.kind == CopyKind.offline &&
            c.isActive,
      )
      .firstOrNull;
  final notifier = ref.read(localCopiesProvider.notifier);
  return [
    if (pulling != null)
      EmberPill(
        label: l.desktopOfflineProgress((pulling.progress * 100).round()),
        icon: MTIcons.offline,
        selected: true,
        onTap: () => notifier.cancel(pulling.id),
      )
    // Removing the only copy of a clip the server no longer has would lose
    // it; that is the library's delete, behind its confirmation.
    else if (item.isOffline && item.onServer)
      EmberPill(
        label: l.removeLocalCopy,
        icon: MTIcons.offline,
        selected: true,
        onTap: () => unawaited(_remove(context, ref, item)),
      )
    else if (!item.isOffline && source != null)
      EmberPill(
        label: l.makeOffline,
        icon: MTIcons.offline,
        selected: false,
        onTap: () => unawaited(_makeOffline(context, ref, source)),
      ),
    if (source != null)
      EmberPill(
        label: l.desktopDownloadTo,
        icon: MTIcons.saveTo,
        selected: false,
        onTap: () => unawaited(_download(context, ref, source)),
      ),
  ];
}

Future<void> _makeOffline(
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

Future<void> _download(
  BuildContext context,
  WidgetRef ref,
  CopySource source,
) async {
  final copies = ref.read(localCopiesProvider.notifier);
  if (!await copies.download(source) || !context.mounted) return;
  final folder = ref.read(localCopiesProvider).last.folder;
  showMTNotice(context, message: context.mtl.desktopSavingTo(folder));
}

Future<void> _remove(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item,
) async {
  await ref.read(localCopiesProvider.notifier).removeLocalCopy(item);
  if (context.mounted) {
    showMTNotice(context, message: context.mtl.desktopLocalCopyRemoved);
  }
}
