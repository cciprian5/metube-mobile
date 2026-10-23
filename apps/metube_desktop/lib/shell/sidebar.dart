import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../router.dart';
import 'shell_metrics.dart';

/// The sidebar: adding a link on top, the places, then settings at the
/// foot. 240 wide with labels, or 72 with icons alone and the labels in
/// tooltips.
class EmberSidebar extends StatelessWidget {
  const EmberSidebar({
    super.key,
    required this.narrow,
    required this.current,
    required this.onGo,
    this.onAdd,
    this.onToggleNarrow,
  });

  final bool narrow;
  final EmberPlace current;
  final ValueChanged<String> onGo;

  /// null until the add dialog exists; the button stays, dimmed.
  final VoidCallback? onAdd;

  /// null when the window is too narrow to offer the wide sidebar.
  final VoidCallback? onToggleNarrow;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    Widget item(EmberPlace place, MTIconData icon, String label, String to) =>
        _SidebarItem(
          icon: icon,
          label: label,
          narrow: narrow,
          selected: current == place,
          onTap: () => onGo(to),
        );

    return AnimatedContainer(
      duration: MTMotion.medium,
      curve: MTMotion.ease,
      width: narrow ? EmberShellSize.sidebarNarrow : EmberShellSize.sidebarWide,
      decoration: BoxDecoration(
        color: p.bg,
        border: BorderDirectional(end: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.all(MTSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AddButton(narrow: narrow, label: l.addLinkFab, onTap: onAdd),
          const SizedBox(height: MTSpace.lg),
          item(
            EmberPlace.library,
            MTIcons.library,
            l.navLibrary,
            EmberRoutes.library,
          ),
          item(
            EmberPlace.favorites,
            MTIcons.favorite,
            l.favorites,
            EmberRoutes.favorites,
          ),
          item(
            EmberPlace.offline,
            MTIcons.download,
            l.filterOffline,
            EmberRoutes.offline,
          ),
          item(
            EmberPlace.search,
            MTIcons.search,
            l.desktopSearch,
            EmberRoutes.search,
          ),
          const SizedBox(height: MTSpace.lg),
          item(
            EmberPlace.playlists,
            MTIcons.queue,
            l.navPlaylists,
            EmberRoutes.playlists,
          ),
          item(
            EmberPlace.channels,
            MTIcons.subscriptions,
            l.desktopChannels,
            EmberRoutes.channels,
          ),
          const Spacer(),
          if (onToggleNarrow case final toggle?)
            _SidebarItem(
              icon: MTIcons.collapse,
              label: narrow ? l.desktopWidenSidebar : l.desktopNarrowSidebar,
              narrow: narrow,
              selected: false,
              onTap: toggle,
            ),
          item(
            EmberPlace.settings,
            MTIcons.settings,
            l.navSettings,
            EmberRoutes.settings,
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.narrow,
    required this.selected,
    required this.onTap,
  });

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
        child: SizedBox(
          height: MTDensity.desktop.row,
          child: narrow
              ? Center(child: glyph)
              : Row(
                  children: [
                    const SizedBox(width: MTSpace.sm),
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
