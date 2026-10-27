import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// A tooltip that teaches the keyboard: the label, then the shortcut in a
/// small key cap ("Download to this computer  Ctrl+D"). Its card comes
/// from the desktop theme's [TooltipThemeData].
///
/// **Shown in an ordinary overlay entry, not Material's [Tooltip]**, which
/// builds an `OverlayPortal`. Flutter 3.47 grafts a portal's overlay node
/// back under the node of the place it was built in, and a node keeps only
/// one such mark: with two tooltips in the same node (a row's grip and its
/// remove button, a bar of buttons), the one shown arrived on Windows with
/// no parent, the accessibility bridge rejected the update it came in, and
/// a tree that loses updates that way can crash the app later (measured).
/// An overlay entry is an ordinary child of the overlay, with nothing to
/// graft.
///
/// Silent to a screen reader, as before: every control under it carries
/// its own name, which Windows would read twice ("Play. Play"), and the
/// key cap is a widget a reader would read as a placeholder character.
class MTShortcutTooltip extends StatefulWidget {
  const MTShortcutTooltip({
    super.key,
    required this.message,
    this.shortcut,
    required this.child,
  });

  final String message;

  /// Shown as written, for example "Ctrl+D". Null shows the label alone.
  final String? shortcut;
  final Widget child;

  @override
  State<MTShortcutTooltip> createState() => _MTShortcutTooltipState();
}

class _MTShortcutTooltipState extends State<MTShortcutTooltip> {
  OverlayEntry? _entry;
  Timer? _wait;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  void _hover() {
    _wait?.cancel();
    final delay =
        TooltipTheme.of(context).waitDuration ??
        const Duration(milliseconds: 500);
    _wait = Timer(delay, _show);
  }

  void _show() {
    if (!mounted || _entry != null || widget.message.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = context.findRenderObject();
    final space = overlay?.context.findRenderObject();
    if (overlay == null ||
        box is! RenderBox ||
        !box.attached ||
        space is! RenderBox) {
      return;
    }
    final target = box.localToGlobal(
      box.size.center(Offset.zero),
      ancestor: space,
    );
    final card = _card(context);
    final direction = Directionality.of(context);
    final gap = math.max(
      TooltipTheme.of(context).verticalOffset ?? MTSpace.xl,
      box.size.height / 2 + MTSpace.xxs,
    );
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Directionality(
              textDirection: direction,
              child: CustomSingleChildLayout(
                delegate: _Below(target: target, gap: gap),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: MTMotion.fast,
                  builder: (context, t, child) =>
                      Opacity(opacity: t, child: child),
                  child: card,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _wait?.cancel();
    _wait = null;
    _entry
      ?..remove()
      ..dispose();
    _entry = null;
  }

  /// The card itself: the theme's decoration and padding around the label
  /// and the key cap.
  Widget _card(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final theme = TooltipTheme.of(context);
    final style = theme.textStyle;
    final key = widget.shortcut;
    return Container(
      decoration: theme.decoration,
      padding: theme.padding,
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(text: widget.message),
            if (key != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  margin: const EdgeInsetsDirectional.only(start: MTSpace.sm),
                  padding: const EdgeInsets.symmetric(horizontal: MTSpace.xxs),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: p.miniInk.withValues(alpha: 0.3),
                      width: MTThemeX.of(context).hairline,
                    ),
                    borderRadius: BorderRadius.circular(MTCorners.desktop.box),
                  ),
                  child: Text(
                    key,
                    style: style?.copyWith(
                      fontSize: Theme.of(context)
                          .textTheme
                          .labelSmall!
                          .fontSize,
                      color: p.miniInk.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _hover(),
    onExit: (_) => _hide(),
    // A click means the pointer is busy with the control: the card goes,
    // as Material's does.
    child: Listener(
      onPointerDown: (_) => _hide(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    ),
  );
}

/// Places the card under its control, or above when there is no room
/// beneath, centred on it and kept inside the window.
class _Below extends SingleChildLayoutDelegate {
  const _Below({required this.target, required this.gap});

  final Offset target;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().deflate(const EdgeInsets.all(MTSpace.sm));

  @override
  Offset getPositionForChild(Size size, Size childSize) => positionDependentBox(
    size: size,
    childSize: childSize,
    target: target,
    verticalOffset: gap,
    preferBelow: true,
    margin: MTSpace.sm,
  );

  @override
  bool shouldRelayout(_Below old) => old.target != target || old.gap != gap;
}
