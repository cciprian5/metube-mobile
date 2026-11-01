import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

// The controls of the Wahaj theme that choose between the ink and the
// accent, kept apart from the theme's surfaces and type.

/// **The switch in the ink** (log §4, 2026-10-31), as Ember's MTSwitch:
/// a settings page has many switches on, and the accent on each of them
/// marked nothing. Off, a hairline track and a quiet knob.
SwitchThemeData mtSwitchTheme(MTPalette p) => SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? p.bg
        : states.contains(WidgetState.disabled)
        ? p.line2
        : p.ink3,
  ),
  trackColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? states.contains(WidgetState.disabled)
              ? p.ink.withValues(alpha: 0.38)
              : p.ink
        : Colors.transparent,
  ),
  trackOutlineColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? Colors.transparent
        : states.contains(WidgetState.disabled)
        ? p.line
        : p.line2,
  ),
  overlayColor: WidgetStatePropertyAll(p.ink.withValues(alpha: mtHoverVeil)),
);

/// A chosen option is the ink, like a chosen chip.
RadioThemeData mtRadioTheme(MTPalette p) => RadioThemeData(
  fillColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected) ? p.ink : p.line2,
  ),
);

/// A hairline square that fills with the ink when on.
CheckboxThemeData mtCheckboxTheme(MTPalette p, MTCorners corners) =>
    CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.box),
      ),
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.ink : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.bg),
    );

/// The chosen section is a pill of the ink's veil, in the ink: an accent
/// on the chrome marked nothing beside the add and play buttons.
NavigationBarThemeData mtNavigationBarTheme(MTPalette p, TextStyle label) =>
    NavigationBarThemeData(
      backgroundColor: p.bg,
      indicatorColor: mtSelectedFill(p),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? label.copyWith(fontWeight: FontWeight.w700, color: p.ink)
            : label.copyWith(color: p.ink2),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? p.ink : p.ink3,
        ),
      ),
    );

/// The rail is the bottom bar turned on its side for wide windows, so it
/// takes the bar's colours and type rather than Material's defaults.
NavigationRailThemeData mtNavigationRailTheme(MTPalette p, TextStyle label) =>
    NavigationRailThemeData(
      backgroundColor: p.bg,
      indicatorColor: mtSelectedFill(p),
      selectedIconTheme: IconThemeData(color: p.ink),
      unselectedIconTheme: IconThemeData(color: p.ink3),
      selectedLabelTextStyle: label.copyWith(
        fontWeight: FontWeight.w700,
        color: p.ink,
      ),
      unselectedLabelTextStyle: label.copyWith(color: p.ink2),
    );

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
