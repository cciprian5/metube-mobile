import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// One of the player bar's icon buttons, ember when its mode is on.
class EmberPlayerControl extends StatelessWidget {
  const EmberPlayerControl({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.shortcut,
    this.color,
  });

  final MTIconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final String? shortcut;

  /// The icon's own colour when on, over the accent: the favourite's red.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final ink = onTap == null
        ? p.ink3
        : (selected ? color ?? p.accentInk : p.ink2);
    return MTShortcutTooltip(
      message: label,
      shortcut: shortcut,
      child: IconButton(
        onPressed: onTap,
        icon: MTIcon(icon, size: MTSpace.lg, color: ink, semanticLabel: label),
      ),
    );
  }
}

/// The player bar's play and pause, filled with the accent.
class EmberPlayButton extends StatelessWidget {
  const EmberPlayButton({
    super.key,
    required this.playing,
    required this.label,
    required this.onTap,
    required this.accent,
    required this.ink,
  });

  final bool playing;
  final String label;
  final VoidCallback? onTap;
  final Color accent;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return MTShortcutTooltip(
      message: label,
      shortcut: 'Space',
      // A bare ink well is only tappable; a screen reader also needs to
      // hear that this is a button, and when it is dimmed.
      child: Semantics(button: true, enabled: onTap != null, child: _face(p)),
    );
  }

  Widget _face(MTPalette p) {
    return Material(
      color: onTap == null ? p.cardAlt : accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTCorners.desktop.fab),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Not the theme's opaque hover fill, which would hide the ember.
        hoverColor: ink.withValues(alpha: 0.12),
        child: SizedBox.square(
          dimension: MTDensity.desktop.row,
          child: Center(
            child: MTIcon(
              playing ? MTIcons.pause : MTIcons.playFill,
              size: MTSpace.lg,
              color: onTap == null ? p.ink3 : ink,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}
