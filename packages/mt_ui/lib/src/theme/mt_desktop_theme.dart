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
    // A page's title (Library, Channels, Settings) is the headline of the
    // display face at its full weight. Left undefined, it fell back to
    // Material's 24 at the regular weight, and every title read thin.
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineLarge,
    ),
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
        // A button that is on (a panel shown, a mode chosen) is filled
        // with the ink, as a chosen sidebar row is.
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? mtSelectedFill(p) : null,
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
    // A charcoal card rather than Material's grey slab, with room for a
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
    // **One coloured action per dialog**: the filled one. A text button
    // beside it (Cancel, Done) is in the ink; in the accent it took the
    // colour while the filled button waited greyed out for a link.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.ink,
        textStyle: base.textTheme.labelLarge,
      ),
    ),
    // Not yet possible, the filled button stays the ember, pale, so it
    // still reads as the one action of the dialog.
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? p.accent.withValues(alpha: mtDisabledAccent)
              : p.accent,
        ),
        // The accent's own dark ink on its pale tint: legible by day and
        // by night, as a disabled control must stay.
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? p.accentInk : p.onAccent,
        ),
      ),
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

/// How much of the ember a filled button keeps while it cannot be pressed.
const double mtDisabledAccent = 0.25;

/// How much of the ink fills whatever is chosen in the chrome: a sidebar
/// row, a settings section, a mode that is on. A step over the hover veil,
/// so a hovered row never reads as the chosen one.
const double mtSelectedVeil = 0.10;

/// **The chosen row is filled with the ink, not the accent.** With the
/// accent on every chosen row, on the add button and on the play button at
/// once, it marked nothing; it is kept for the one action and for the data
/// that follows playback.
Color mtSelectedFill(MTPalette p) => p.ink.withValues(alpha: mtSelectedVeil);
