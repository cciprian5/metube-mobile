import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'mt_video_screen.dart';

/// The portrait player's actions as one row of pills: the main one outlined
/// in the ink, then the rest, then a ⋮ holding what is used less (sharing,
/// the original link). It scrolls sideways rather than squeeze: five equal
/// boxes with labels of 9.5 points read as a form, and a long label broke
/// onto two lines.
class MTVideoActionsRow extends StatelessWidget {
  const MTVideoActionsRow({
    super.key,
    required this.actions,
    this.bleed = MTSpace.pagePad,
  });

  final List<MTPlayerAction> actions;

  /// The margin the sheet keeps on each side, which the row runs into.
  final double bleed;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final a in actions)
        if (!a.inMenu) a,
    ];
    final menu = [
      for (final a in actions)
        if (a.inMenu) a,
    ];
    // **Out to the screen's edges**, its first pill still in line with the
    // title: cut at the page margin, the last whole pill read as the end
    // of the row and nobody found what lay past it. Now the next one
    // peeks in at the edge.
    // IntrinsicHeight hands the box the pills' own height, which grows
    // with the system's text size; the box alone would ask for all of it.
    return LayoutBuilder(
      builder: (context, box) => IntrinsicHeight(
        child: OverflowBox(
          minWidth: box.maxWidth + 2 * bleed,
          maxWidth: box.maxWidth + 2 * bleed,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: bleed),
            child: _row(context, shown, menu),
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    List<MTPlayerAction> shown,
    List<MTPlayerAction> menu,
  ) => Row(
    children: [
      for (final action in shown) ...[
        _Pill(
          icon: action.icon,
          label: action.label,
          onTap: action.onTap,
          strong: action.main || action.highlighted,
        ),
        const SizedBox(width: MTSpace.sm),
      ],
      if (menu.isNotEmpty)
        _Pill(
          icon: MTIcons.moreVert,
          tooltip: context.mtl.itemOptions,
          onTap: () => _showMenu(context, menu),
        ),
    ],
  );

  static void _showMenu(BuildContext context, List<MTPlayerAction> menu) {
    final p = MTThemeX.of(context).palette;
    showMTSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(
          top: MTSpace.md,
          bottom: mtSheetBottomPad(sheet, MTSpace.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in menu)
              ListTile(
                leading: MTIcon(action.icon, color: p.ink2),
                title: Text(action.label),
                onTap: () {
                  Navigator.of(sheet).pop();
                  action.onTap();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    this.strong = false,
  });

  final MTIconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final shape = StadiumBorder(
      side: BorderSide(color: strong ? p.ink : p.line2),
    );
    final pill = Material(
      color: Colors.transparent,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: ConstrainedBox(
          // A finger's height, as every other target on the phone.
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label == null ? MTSpace.sm + 2 : MTSpace.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A favourite's heart is crimson here as on every card.
                MTIcon(
                  icon,
                  size: 18,
                  color: icon == MTIcons.favoriteOn ? p.favorite : p.ink,
                ),
                if (label case final label?) ...[
                  const SizedBox(width: MTSpace.xs + 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: p.ink,
                      fontSize: 13,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}
