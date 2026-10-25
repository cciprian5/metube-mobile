import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../router.dart';
import '../../shell/context_menu.dart';
import '../lists/list_dialogs.dart';
import 'clip_actions.dart';

enum _ClipChoice { addToList, copyLink, openOriginal, delete }

/// The right-click menu of a clip's page: the actions that do not earn a
/// button, in the phone's order, **deleting from the server last** and only
/// here, behind a confirmation.
Future<void> showClipMenu(
  BuildContext context,
  WidgetRef ref,
  Offset globalPosition,
  PlaylistItem item,
) async {
  final l = context.mtl;
  final choice = await showEmberMenu(context, globalPosition, [
    EmberMenuEntry(_ClipChoice.addToList, MTIcons.queue, l.addToPlaylist),
    EmberMenuEntry(_ClipChoice.copyLink, MTIcons.link, l.desktopCopyLink),
    EmberMenuEntry(
      _ClipChoice.openOriginal,
      MTIcons.external,
      l.openOriginalLink,
    ),
    const EmberMenuEntry.divider(),
    EmberMenuEntry(
      _ClipChoice.delete,
      MTIcons.trash,
      l.deleteFromServer,
      danger: true,
    ),
  ]);
  if (choice == null || !context.mounted) return;
  final actions = ref.read(clipActionsProvider);
  switch (choice) {
    case _ClipChoice.addToList:
      await showAddToPlaylistDialog(context, item);
    case _ClipChoice.copyLink:
      await Clipboard.setData(ClipboardData(text: item.canonicalUrl));
      if (context.mounted) showMTNotice(context, message: l.desktopLinkCopied);
    case _ClipChoice.openOriginal:
      await actions.openOriginal(item.canonicalUrl);
    case _ClipChoice.delete:
      final sure = await showMTConfirm(
        context,
        title: l.deleteFromServer,
        message: l.deleteFromServerConfirm,
        confirmLabel: l.delete,
        cancelLabel: l.cancel,
        destructive: true,
      );
      if (!sure || !context.mounted) return;
      final router = GoRouter.of(context);
      await actions.deleteFromServer(item.canonicalUrl);
      if (!context.mounted) return;
      showMTNotice(context, message: l.deletedFromServer);
      router.go(EmberRoutes.library);
  }
}

/// Carries a right click anywhere inside [child] to [showClipMenu].
class ClipMenuArea extends ConsumerWidget {
  const ClipMenuArea({super.key, required this.item, required this.child});

  final PlaylistItem item;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    // Only the right click is caught here; left in, Flutter would offer a
    // screen reader a "tap" on the whole area that does nothing.
    excludeFromSemantics: true,
    onSecondaryTapUp: (d) =>
        unawaited(showClipMenu(context, ref, d.globalPosition, item)),
    child: child,
  );
}
