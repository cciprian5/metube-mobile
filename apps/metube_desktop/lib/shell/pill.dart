import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The rounded choice used for the panel's tabs and the library's filter
/// chips: a hairline outline, and filled with ink when chosen.
class EmberPill extends StatelessWidget {
  const EmberPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.mirrored = false,
    this.struck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final MTIconData? icon;

  /// Turned to face the reading direction in Arabic: "back" points right
  /// there.
  final bool mirrored;

  /// An excluded filter: drawn crossed out rather than chosen.
  final bool struck;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final ink = selected ? p.bg : (struck ? p.err : p.ink2);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.ink : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? p.ink : (struck ? p.err : p.line2),
            width: MTThemeX.of(context).hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // **A fresh ink layer whenever the choice flips** (seen on the
          // real window): the hover highlight made before a click kept the
          // opaque light fill it was created with, and covered the newly
          // chosen pill's cream label for as long as the pointer stayed.
          key: ValueKey(selected),
          onTap: onTap,
          // A chosen pill only lightens a little under the pointer; the
          // theme's light fills would hide its label.
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.isEmpty) return null;
            if (selected) return p.bg.withValues(alpha: 0.12);
            return states.contains(WidgetState.pressed)
                ? p.accentSoft
                : p.cardAlt;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md,
              vertical: MTSpace.xs,
            ),
            // A label wider than the room it is given (a long tag, a large
            // font) shortens with an ellipsis; given unbounded room, in a
            // row of pills, it keeps its full width.
            child: LayoutBuilder(
              builder: (context, box) {
                final text = Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ink,
                    decoration: struck ? TextDecoration.lineThrough : null,
                    decorationColor: ink,
                  ),
                );
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon case final glyph?) ...[
                      Transform.flip(
                        flipX:
                            mirrored &&
                            Directionality.of(context) == TextDirection.rtl,
                        child: MTIcon(glyph, size: MTSpace.md, color: ink),
                      ),
                      const SizedBox(width: MTSpace.xxs),
                    ],
                    if (box.hasBoundedWidth) Flexible(child: text) else text,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
