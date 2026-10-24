import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The sidebar's add button: the ember, with the label when wide.
class SidebarAddButton extends StatelessWidget {
  const SidebarAddButton({
    super.key,
    required this.narrow,
    required this.label,
    required this.onTap,
  });

  final bool narrow;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final corners = MTCorners.desktop;
    final ink = onTap == null ? p.ink3 : p.onAccent;
    final plus = MTIcon(MTIcons.plus, size: MTSpace.lg, color: ink);
    return MTShortcutTooltip(
      message: label,
      shortcut: 'Ctrl+V',
      child: Material(
        color: onTap == null ? p.cardAlt : p.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corners.field),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Not the theme's opaque hover fill, which would hide the ember.
          hoverColor: p.onAccent.withValues(alpha: 0.12),
          child: SizedBox(
            height: MTDensity.desktop.row + MTSpace.xxs,
            child: narrow
                ? Center(child: plus)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      plus,
                      const SizedBox(width: MTSpace.xs),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: ink),
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

/// One place in the sidebar: its icon, and its label when wide (in a
/// tooltip when narrow).
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.narrow,
    required this.selected,
    required this.onTap,
    this.indent = false,
    this.depth = 0,
    this.trailing,
    this.onMenu,
  });

  /// A right click, at where it landed; null when the place has no menu.
  final ValueChanged<Offset>? onMenu;

  /// A pinned list, set in under "Playlists".
  final bool indent;

  /// A folder's level in the tree, each one set in further.
  final int depth;

  /// A count at the line's end.
  final String? trailing;

  final MTIconData icon;
  final String label;
  final bool narrow;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final ink = selected ? p.accentInk : p.ink2;
    final glyph = MTIcon(icon, size: MTSpace.lg, color: ink);
    final row = Material(
      color: selected ? p.accentSoft : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTCorners.desktop.chip),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapUp: onMenu == null
            ? null
            : (d) => onMenu!(d.globalPosition),
        child: SizedBox(
          height: MTDensity.desktop.row,
          child: narrow
              ? Center(child: glyph)
              : Row(
                  children: [
                    SizedBox(
                      width: indent
                          ? MTSpace.xl
                          : MTSpace.sm + MTSpace.md * depth,
                    ),
                    glyph,
                    const SizedBox(width: MTSpace.sm),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected ? p.accentInk : p.ink,
                          fontWeight: selected ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    if (trailing case final count?)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: MTSpace.xs,
                          end: MTSpace.sm,
                        ),
                        child: Text(
                          count,
                          style: Theme.of(context).textTheme.labelSmall?.tabular
                              .copyWith(color: p.ink3),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      label: narrow ? label : null,
      child: narrow ? MTShortcutTooltip(message: label, child: row) : row,
    );
  }
}
