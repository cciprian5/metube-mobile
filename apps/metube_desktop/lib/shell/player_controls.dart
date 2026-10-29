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
    this.ink,
  });

  final MTIconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final String? shortcut;

  /// The icon's own colour when on, over the accent: the favourite's red.
  final Color? color;

  /// The icon's colour when off, over the theme's: white on a picture.
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final ink = onTap == null
        ? p.ink3
        : (selected ? color ?? p.ink : this.ink ?? p.ink2);
    // The veil under the mouse is of the glyph's own colour: white over a
    // picture, the ink elsewhere.
    final veil = switch (this.ink) {
      final light? => light.withValues(alpha: mtHoverVeil * 3),
      null => p.ink.withValues(alpha: mtHoverVeil),
    };
    return MTShortcutTooltip(
      message: label,
      shortcut: shortcut,
      // A hair of space each side, so the veils of two neighbours under
      // the mouse never touch.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MTSpace.xxs / 2),
        child: _button(p, ink, veil),
      ),
    );
  }

  Widget _button(MTPalette p, Color ink, Color veil) => IconButton(
    onPressed: onTap,
    // A mode or a layout that is on is read as on.
    isSelected: selected,
    // **On is filled, not only tinted**: a mode turned on (repeat,
    // shuffle) showed only as a change of the glyph's colour, which
    // could not be told apart at a glance.
    style: IconButton.styleFrom(
      backgroundColor: selected && this.ink == null ? mtSelectedFill(p) : null,
      hoverColor: veil,
    ),
    // A mode turned on or off, or the heart filled, swaps its glyph in
    // place rather than jumping.
    icon: MTIconSwap(
      wahaj: icon,
      size: MTDensity.desktop.icon,
      color: ink,
      semanticLabel: label,
    ),
  );
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
            child: MTIconSwap(
              wahaj: playing ? MTIcons.pause : MTIcons.playFill,
              size: MTDensity.desktop.icon,
              color: onTap == null ? p.ink3 : ink,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}
