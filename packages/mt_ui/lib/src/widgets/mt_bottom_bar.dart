import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'mt_adaptive.dart';
import 'mt_polish.dart';

/// The phone's bottom bar, with **one pill that slides** to the section
/// chosen. Material's bar grows a fresh pill under each destination, which
/// reads as three separate switches; the sections are places side by side,
/// and a pill travelling between them says so.
///
/// Colours, height and type come from the theme's `NavigationBarTheme`,
/// so it looks as the bar did.
class MTBottomBar extends StatelessWidget {
  const MTBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<MTNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// The pill behind the chosen icon.
  static const Size pill = Size(64, 32);

  /// Space above the pill. Fixed, so the pill and the icons stay level
  /// however tall a larger text size makes the labels.
  static const double top = 10;

  @override
  Widget build(BuildContext context) {
    final theme = NavigationBarTheme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final slide = mtMotionDuration(context, MTMotion.page);
    final fade = mtMotionDuration(context, MTMotion.fast);
    return Material(
      color: theme.backgroundColor,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.height ?? 68),
          child: LayoutBuilder(
            builder: (context, box) {
              final cell = box.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositionedDirectional(
                    duration: slide,
                    curve: MTMotion.entrance,
                    start: cell * selectedIndex + (cell - pill.width) / 2,
                    top: top,
                    width: pill.width,
                    height: pill.height,
                    child: DecoratedBox(
                      key: const ValueKey('bar-pill'),
                      decoration: ShapeDecoration(
                        color: theme.indicatorColor,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, item) in items.indexed)
                        Expanded(
                          child: _Destination(
                            item: item,
                            selected: i == selectedIndex,
                            hint: localizations.tabLabel(
                              tabIndex: i + 1,
                              tabCount: items.length,
                            ),
                            fade: fade,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.item,
    required this.selected,
    required this.hint,
    required this.fade,
    required this.onTap,
  });

  final MTNavItem item;
  final bool selected;
  final String hint;
  final Duration fade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NavigationBarTheme.of(context);
    final states = {if (selected) WidgetState.selected};
    final icon = theme.iconTheme?.resolve(states);
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: item.label,
      hint: hint,
      child: InkWell(
        onTap: onTap,
        // The label above says it; the tap stays on this node.
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(
              top: MTBottomBar.top,
              bottom: MTSpace.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: MTBottomBar.pill.height,
                  child: Center(
                    child: MTIconSwap(
                      icon: selected ? item.selectedIcon : item.icon,
                      color: icon?.color,
                      size: icon?.size,
                    ),
                  ),
                ),
                const SizedBox(height: MTSpace.xs),
                AnimatedDefaultTextStyle(
                  duration: fade,
                  style:
                      theme.labelTextStyle?.resolve(states) ??
                      DefaultTextStyle.of(context).style,
                  textAlign: TextAlign.center,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
