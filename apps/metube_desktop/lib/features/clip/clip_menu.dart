import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../router.dart';
import 'clip_actions.dart';

enum _ClipChoice { copyLink, openOriginal, delete }

/// The right-click menu of a clip's page: the actions that do not earn a
/// button, in the phone's order, **deleting from the server last** and only
/// here, behind a confirmation.
///
/// [globalPosition] is where the click landed in the window. The menu is
/// laid out in the overlay, which the interface size scales, so the point
/// is carried into the overlay's own coordinates first; used raw it lands
/// off the pointer at any size but 100%.
Future<void> showClipMenu(
  BuildContext context,
  WidgetRef ref,
  Offset globalPosition,
  PlaylistItem item,
) async {
  final l = context.mtl;
  final p = MTThemeX.of(context).palette;
  final text = Theme.of(context).textTheme;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final at = overlay.globalToLocal(globalPosition);

  PopupMenuItem<_ClipChoice> row(
    _ClipChoice value,
    MTIconData icon,
    String label, {
    bool danger = false,
  }) {
    final color = danger ? p.err : p.ink;
    return PopupMenuItem(
      value: value,
      height: MTDensity.desktop.row,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MTIcon(icon, size: MTSpace.lg, color: danger ? p.err : p.ink2),
          const SizedBox(width: MTSpace.sm),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  final choice = await showMenu<_ClipChoice>(
    context: context,
    position: RelativeRect.fromRect(at & Size.zero, Offset.zero & overlay.size),
    color: p.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MTCorners.desktop.card),
      side: BorderSide(color: p.line2),
    ),
    items: [
      row(_ClipChoice.copyLink, MTIcons.link, l.desktopCopyLink),
      row(_ClipChoice.openOriginal, MTIcons.external, l.openOriginalLink),
      const PopupMenuDivider(),
      row(_ClipChoice.delete, MTIcons.trash, l.deleteFromServer, danger: true),
    ],
  );
  if (choice == null || !context.mounted) return;
  final actions = ref.read(clipActionsProvider);
  switch (choice) {
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
    onSecondaryTapUp: (d) =>
        unawaited(showClipMenu(context, ref, d.globalPosition, item)),
    child: child,
  );
}
