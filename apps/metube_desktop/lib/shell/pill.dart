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
    this.struck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final MTIconData? icon;

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
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md,
              vertical: MTSpace.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final glyph?) ...[
                  MTIcon(glyph, size: MTSpace.md, color: ink),
                  const SizedBox(width: MTSpace.xxs),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ink,
                    decoration: struck ? TextDecoration.lineThrough : null,
                    decorationColor: ink,
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
