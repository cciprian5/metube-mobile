import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'nav_history.dart';

/// Above the content: back and forward, the search box, and the button
/// that shows or hides the side panel.
class EmberContentBar extends StatelessWidget {
  const EmberContentBar({
    super.key,
    required this.history,
    required this.onSearch,
    required this.panelShown,
    required this.onTogglePanel,
  });

  final NavHistory history;
  final VoidCallback onSearch;
  final bool panelShown;
  final VoidCallback onTogglePanel;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.xl,
        MTSpace.md,
        MTSpace.xl,
        MTSpace.sm,
      ),
      child: Row(
        children: [
          ListenableBuilder(
            listenable: history,
            // The arrows point the way the page turns: in Arabic "back"
            // points right.
            builder: (context, _) => Row(
              children: [
                _BarButton(
                  icon: MTIcons.back,
                  label: l.desktopBack,
                  shortcut: 'Alt+←',
                  onTap: history.canGoBack ? history.back : null,
                  mirrored: true,
                ),
                _BarButton(
                  icon: MTIcons.forward,
                  label: l.desktopForward,
                  shortcut: 'Alt+→',
                  onTap: history.canGoForward ? history.forward : null,
                  mirrored: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: MTSpace.sm),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: MTBreakpoint.readable / 2,
                ),
                child: _SearchBox(hint: l.desktopSearchHint, onTap: onSearch),
              ),
            ),
          ),
          const SizedBox(width: MTSpace.sm),
          _BarButton(
            icon: MTIcons.transcript,
            label: panelShown ? l.desktopHidePanel : l.desktopShowPanel,
            onTap: onTogglePanel,
            selected: panelShown,
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.shortcut,
    this.selected = false,
    this.mirrored = false,
  });

  final MTIconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback? onTap;
  final bool selected;

  /// An arrow that turns with the reading direction.
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final ink = onTap == null ? p.ink3 : (selected ? p.accentInk : p.ink2);
    return MTShortcutTooltip(
      message: label,
      shortcut: shortcut,
      child: IconButton(
        onPressed: onTap,
        isSelected: selected,
        icon: Transform.flip(
          flipX: mirrored && Directionality.of(context) == TextDirection.rtl,
          child: MTIcon(
            icon,
            size: MTSpace.lg,
            color: ink,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}

/// Looks like a field and opens the search place; the real search, with
/// its command palette, comes with the search screen.
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final corners = MTCorners.desktop;
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corners.field),
          side: BorderSide(color: p.line2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: MTDensity.desktop.row,
            child: Row(
              children: [
                const SizedBox(width: MTSpace.md),
                MTIcon(MTIcons.search, size: MTSpace.lg, color: p.ink3),
                const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: p.ink3),
                  ),
                ),
                _KeyCap(label: 'Ctrl K'),
                const SizedBox(width: MTSpace.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: p.line2),
          borderRadius: BorderRadius.circular(MTCorners.desktop.box),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpace.xs,
            vertical: MTSpace.xxs / 2,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: p.ink3),
          ),
        ),
      ),
    );
  }
}
