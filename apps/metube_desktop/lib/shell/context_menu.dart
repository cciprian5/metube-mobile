import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';

/// One line of a right-click menu; null [value] draws a divider.
class EmberMenuEntry<T> {
  const EmberMenuEntry(this.value, this.icon, this.label, {this.danger = false})
    : assert(value != null);

  const EmberMenuEntry.divider()
    : value = null,
      icon = null,
      label = '',
      danger = false;

  final T? value;
  final MTIconData? icon;
  final String label;

  /// Drawn in the error colour: deleting, unfollowing. Kept last.
  final bool danger;
}

/// The Wahaj right-click menu: a card sheet with a hairline, one row per
/// action with its icon, opened at the pointer.
///
/// [globalPosition] is where the click landed in the window. The menu is
/// laid out in the overlay, which the interface size scales, so the point
/// is carried into the overlay's own coordinates first; used raw it lands
/// off the pointer at any size but 100%.
Future<T?> showEmberMenu<T>(
  BuildContext context,
  Offset globalPosition,
  List<EmberMenuEntry<T>> entries,
) {
  final p = MTThemeX.of(context).palette;
  final text = Theme.of(context).textTheme;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final at = overlay.globalToLocal(globalPosition);
  final size = overlay.size;
  return showMenu<T>(
    context: context,
    // The menu opens on the reading side of the pointer, as Windows' own
    // do: rightwards in English, leftwards in Arabic, and only turns back
    // at the window's edge. Given a point, Flutter opens it towards the
    // wider half instead; insets that do not mirror each other tell it
    // which edge to align.
    position: Directionality.of(context) == TextDirection.rtl
        ? RelativeRect.fromLTRB(
            size.width,
            at.dy,
            size.width - at.dx,
            size.height - at.dy,
          )
        : RelativeRect.fromLTRB(at.dx, at.dy, size.width, size.height - at.dy),
    color: p.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MTCorners.desktop.card),
      side: BorderSide(color: p.line2, width: MTThemeX.of(context).hairline),
    ),
    items: [
      for (final entry in entries)
        if (entry.value case final value?)
          PopupMenuItem<T>(
            value: value,
            height: MTDensity.desktop.row,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.icon case final icon?) ...[
                  MTIcon(
                    icon,
                    size: MTSpace.lg,
                    color: entry.danger ? p.err : p.ink2,
                  ),
                  const SizedBox(width: MTSpace.sm),
                ],
                Flexible(
                  child: Text(
                    entry.label,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: entry.danger ? p.err : p.ink,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const PopupMenuDivider(),
    ],
  );
}

/// The keyboard's way to a right-click menu: the menu key, or Shift+F10,
/// pressed on whatever has focus inside [child] opens [onMenu] at the
/// middle of [child], as Windows' own lists do.
class MenuKey extends StatelessWidget {
  const MenuKey({super.key, required this.onMenu, required this.child});

  final ValueChanged<Offset>? onMenu;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onMenu = this.onMenu;
    if (onMenu == null) return child;
    void open() {
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached) return;
      onMenu(box.localToGlobal(box.size.center(Offset.zero)));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.contextMenu): open,
        const SingleActivator(LogicalKeyboardKey.f10, shift: true): open,
      },
      child: child,
    );
  }
}
