import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/mt_motion.dart';
import 'mt_theme.dart';

/// The Windows app's theme: the Wahaj theme with the desktop type and
/// corner scales, and the Wahaj components in place of Material's defaults.
///
/// **A separate entry point, not options on [mtTheme]**: the phone apps
/// call [mtTheme] and get exactly what they had; nothing here can reach
/// them.
ThemeData mtDesktopTheme(
  MTVariant variant,
  Brightness brightness, {
  bool highContrast = false,
}) {
  const corners = MTCorners.desktop;
  // With Windows' high contrast on, every rule and border is drawn twice
  // as thick: thin lines are the first thing such eyes lose.
  final line = highContrast ? 2.0 : 1.0;
  final base = mtTheme(
    variant,
    brightness,
    type: MTTypeScale.desktop,
    corners: corners,
    hairline: line,
  );
  final p = MTPalette.of(variant, brightness);
  final hairline = BorderSide(color: p.line2, width: 1.6 * line);

  return base.copyWith(
    // "Warmth" instead of Material's sparkle: a press fills with the soft
    // accent and fades, with no ripple travelling across the control.
    splashFactory: NoSplash.splashFactory,
    // Every platform, so tests (which run as Android) see what Windows
    // shows.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const MTDesktopPageTransition(),
      },
    ),
    highlightColor: p.accentSoft,
    // **A veil of the ink, never an opaque fill**: hovered, a button over
    // a picture or the ember (a play button, the controls on a video)
    // kept its glyph in sight. The opaque card fill covered a white glyph
    // in the day and turned a dark square at night.
    hoverColor: p.ink.withValues(alpha: mtHoverVeil),
    // No filled square on keyboard focus: the ring drawn by
    // MTFocusRingLayer marks it instead, and only for the keyboard.
    focusColor: Colors.transparent,
    // A thin thumb that comes with the mouse or a scroll and leaves
    // again, darker while dragged; never Windows' wide grey bar.
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStatePropertyAll(MTDensity.desktop.scrollbar),
      radius: Radius.circular(MTDensity.desktop.scrollbar / 2),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.dragged) ? p.ink3 : p.line2,
      ),
      thumbVisibility: const WidgetStatePropertyAll(false),
      trackVisibility: const WidgetStatePropertyAll(false),
      interactive: true,
    ),
    // Square icon buttons with small corners; pressed, they warm up.
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        fixedSize: WidgetStatePropertyAll(
          Size.square(MTDensity.desktop.iconButton),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(corners.iconButton),
          ),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.pressed) ? p.accentInk : p.ink2,
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? p.accent.withValues(alpha: mtPressVeil)
              : states.contains(WidgetState.hovered)
              ? p.ink.withValues(alpha: mtHoverVeil)
              : null,
        ),
      ),
    ),
    // A hairline square with small corners; on, it fills with the accent.
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.box),
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide(color: p.accent, width: 1.6 * line)
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
      waitDuration: const Duration(milliseconds: 600),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.dialog),
        side: BorderSide(color: p.line2, width: line),
      ),
    ),
  );
}

/// How much of the ink a hovered control is veiled with: about the card's
/// own step from the page, in day and night alike.
const double mtHoverVeil = 0.07;

/// How much of the ember a pressed control is veiled with.
const double mtPressVeil = 0.16;
