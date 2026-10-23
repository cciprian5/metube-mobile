import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'mt_theme.dart';

/// The Windows app's theme: the Wahaj theme with the desktop type and
/// corner scales, and the Wahaj components in place of Material's defaults.
///
/// **A separate entry point, not options on [mtTheme]**: the phone apps
/// call [mtTheme] and get exactly what they had; nothing here can reach
/// them.
ThemeData mtDesktopTheme(MTVariant variant, Brightness brightness) {
  const corners = MTCorners.desktop;
  final base = mtTheme(
    variant,
    brightness,
    type: MTTypeScale.desktop,
    corners: corners,
  );
  final p = MTPalette.of(variant, brightness);
  final hairline = BorderSide(color: p.line2, width: 1.6);

  return base.copyWith(
    // A hairline square with small corners; on, it fills with the accent.
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.box),
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide(color: p.accent, width: 1.6)
            : hairline,
      ),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? p.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.onAccent),
    ),
    // The ember in a ring: the ring stays a hairline until chosen.
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.line2,
      ),
    ),
    // An espresso card rather than Material's grey slab, with room for a
    // shortcut beside the label (see MTShortcutTooltip).
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.miniBg,
        borderRadius: BorderRadius.circular(corners.tooltip),
        boxShadow: [
          BoxShadow(
            color: p.ink.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -12,
          ),
        ],
      ),
      textStyle: base.textTheme.labelMedium!.copyWith(color: p.miniInk),
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.sm,
        vertical: MTSpace.xs,
      ),
      waitDuration: const Duration(milliseconds: 500),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.dialog),
        side: BorderSide(color: p.line2),
      ),
    ),
  );
}
