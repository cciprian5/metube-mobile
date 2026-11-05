import 'package:flutter/material.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icons.dart';
import '../tokens/tokens.dart';
import '../widgets/mt_page_motion.dart';
import 'mt_theme_controls.dart';
import 'mt_theme_x.dart';

export 'mt_theme_x.dart';

/// The Wahaj theme. **A documented lesson**: the five surfaceContainer*
/// roles must be set explicitly, or Material 3 imposes its own greys over
/// the stone ground.
ThemeData mtTheme(
  MTVariant variant,
  Brightness brightness, {
  MTTypeScale type = MTTypeScale.mobile,
  MTCorners corners = MTCorners.mobile,
  double hairline = 1,
}) {
  final p = MTPalette.of(variant, brightness);
  final isDark = brightness == Brightness.dark;

  // The surface ladder, derived from bg to card to cardAlt at the
  // palette's own hue.
  final (lowest, low, container, high, highest) = isDark
      ? variant == MTVariant.lite
            ? (
                const Color(0xFF101516),
                const Color(0xFF1A2122),
                const Color(0xFF1E2627),
                const Color(0xFF253030),
                const Color(0xFF2C3839),
              )
            : (
                const Color(0xFF121110),
                const Color(0xFF1B1917),
                const Color(0xFF211E1B),
                const Color(0xFF2A2622),
                const Color(0xFF322E2A),
              )
      : (
          const Color(0xFFFFFFFF),
          const Color(0xFFF8F6F3),
          const Color(0xFFEFECE7),
          const Color(0xFFEAE7E1),
          const Color(0xFFE3DFD8),
        );

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.accentInk,
    secondary: p.offline,
    onSecondary: p.bg,
    secondaryContainer: p.offlineSoft,
    onSecondaryContainer: p.offlineInk,
    tertiary: p.favorite,
    onTertiary: p.favoriteSoft,
    error: p.err,
    onError: p.bg,
    surface: p.bg,
    onSurface: p.ink,
    onSurfaceVariant: p.ink2,
    outline: p.line2,
    outlineVariant: p.line,
    surfaceContainerLowest: lowest,
    surfaceContainerLow: low,
    surfaceContainer: container,
    surfaceContainerHigh: high,
    surfaceContainerHighest: highest,
    inverseSurface: p.miniBg,
    onInverseSurface: p.miniInk,
    inversePrimary: p.accentSoft,
    shadow: const Color(0xFF50371E),
    scrim: p.ink.withValues(alpha: 0.5),
  );

  TextStyle display(double size, FontWeight weight) => TextStyle(
    fontFamily: MTType.display,
    package: MTType.package,
    fontWeight: weight,
    fontSize: size,
    color: p.ink,
    height: 1.4,
  );
  TextStyle body(double size, FontWeight weight, {Color? color}) => TextStyle(
    fontFamily: MTType.body,
    package: MTType.package,
    fontWeight: weight,
    fontSize: size,
    color: color ?? p.ink,
    height: 1.55,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: 'packages/${MTType.package}/${MTType.body}',
    // "Warmth" instead of the sparkle: a press fills with the soft accent
    // and fades, with no ripple of particles across the control.
    splashFactory: NoSplash.splashFactory,
    highlightColor: p.accentSoft,
    // Screen transitions slide horizontally and respect the text direction,
    // instead of the default vertical rise that says nothing about how the
    // two screens relate.
    pageTransitionsTheme: mtPageTransitionsTheme,
    // The back and close buttons Flutter draws by itself (an app bar's
    // leading arrow) take the Wahaj glyphs, like every other icon.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) =>
          const MTIcon(MTIcons.back, matchTextDirection: true),
      closeButtonIconBuilder: (_) => const MTIcon(MTIcons.close),
    ),
    dividerTheme: DividerThemeData(
      color: p.line,
      thickness: hairline,
      space: 1,
    ),
    textTheme: TextTheme(
      headlineLarge: display(type.headline, FontWeight.w700),
      headlineMedium: display(20, FontWeight.w700),
      titleLarge: display(17, FontWeight.w700),
      titleMedium: display(14, FontWeight.w700),
      titleSmall: display(12.5, FontWeight.w500),
      bodyLarge: body(type.body, FontWeight.w400),
      bodyMedium: body(13.5, FontWeight.w400),
      bodySmall: body(type.secondary, FontWeight.w400, color: p.ink3),
      labelLarge: body(13.5, FontWeight.w700),
      labelMedium: body(12.5, FontWeight.w500),
      labelSmall: body(10.5, FontWeight.w500, color: p.ink3),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: display(type.headline, FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.card),
        side: BorderSide(color: p.line, width: hairline),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: p.ink,
      side: BorderSide(color: p.line2, width: hairline),
      // **Label colour follows the state** (full review 2026-09-02): a
      // selected chip is painted with `p.ink` as its background and its
      // label was `p.ink2`, dark ink on dark ink, so **a selected tag could
      // not be read**. Screens that passed their own `labelStyle` were
      // hiding the defect; the tags sheet, which uses a bare `FilterChip`,
      // exposed it.
      labelStyle: body(12.5, FontWeight.w500).copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.bg : p.ink2,
        ),
      ),
      checkmarkColor: p.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.chip),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.md,
        vertical: MTSpace.xs,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: body(13.5, FontWeight.w400, color: p.ink3),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MTSpace.lg,
        vertical: MTSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(corners.field),
        borderSide: BorderSide(color: p.line2, width: hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(corners.field),
        borderSide: BorderSide(color: p.line2, width: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(corners.field),
        borderSide: BorderSide(color: p.ink, width: 1.4 * hairline),
      ),
    ),
    // **One coloured action per screen** (log §4, 2026-10-31): the filled
    // button. A text button beside it (Cancel, Done) is in the ink; in the
    // accent it took the colour from the action it sits next to.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.ink,
        textStyle: body(13.5, FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            textStyle: body(13.5, FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(corners.button),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.xl,
              vertical: MTSpace.md,
            ),
          ).copyWith(
            // Not yet possible, it stays the ember, pale, so it still reads as
            // the one action; its label in the accent's own dark ink stays
            // legible by day and by night.
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? p.accent.withValues(alpha: mtDisabledAccent)
                  : p.accent,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? p.accentInk
                  : p.onAccent,
            ),
          ),
    ),
    dialogTheme: mtDialogTheme(
      p,
      corners,
      hairline: hairline,
      title: display(18, FontWeight.w700),
    ),
    switchTheme: mtSwitchTheme(p),
    radioTheme: mtRadioTheme(p),
    checkboxTheme: mtCheckboxTheme(p, corners, hairline: hairline),
    tooltipTheme: mtTooltipTheme(p, corners),
    // Material 3 tints the selected state with secondaryContainer, which is
    // the olive that means "offline" in this design language (log §4). The
    // chosen segment is the ink, as a chosen chip is: the accent is kept for
    // the action, not for a choice (log §4, 2026-10-31).
    segmentedButtonTheme: SegmentedButtonThemeData(
      // The chosen segment's tick is the Wahaj one, not Material's glyph.
      selectedIcon: const MTIcon(MTIcons.check),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.ink
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.bg : p.ink2,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: p.line2, width: hairline),
        ),
        textStyle: WidgetStatePropertyAll(body(13, FontWeight.w500)),
      ),
    ),
    navigationBarTheme: mtNavigationBarTheme(p, body(11.5, FontWeight.w500)),
    navigationRailTheme: mtNavigationRailTheme(p, body(11.5, FontWeight.w500)),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      // **One drag handle for all eighteen sheets** (review 2026-09-02: not
      // a single sheet had one). Setting it in the theme rather than in
      // each sheet is what stops the nineteenth sheet from being built
      // without one, which is exactly how an interface starts to look
      // assembled from different eras.
      showDragHandle: true,
      dragHandleColor: p.line2,
      dragHandleSize: const Size(38, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(corners.sheet),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.miniBg,
      contentTextStyle: body(13.5, FontWeight.w500, color: p.miniInk),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.card),
      ),
    ),
    extensions: [MTThemeX(palette: p, variant: variant, hairline: hairline)],
  );
}
