import 'package:flutter/widgets.dart';

import 'palette.dart';

/// Warm shadows, copied from the reference values.
abstract final class MTShadow {
  /// Daylight card shadow: 0 3 6 at 5% plus 0 30 60 -22 at 22%, in a warm
  /// brown.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D50371E), blurRadius: 6, offset: Offset(0, 3)),
    BoxShadow(
      color: Color(0x3850371E),
      blurRadius: 60,
      offset: Offset(0, 30),
      spreadRadius: -22,
    ),
  ];

  /// What floats over a page (the add button): a short neutral shadow,
  /// 0 8 16 -10. A glow in the accent read as decoration rather than depth
  /// (log §4, 2026-10-31).
  static const List<BoxShadow> float = [
    BoxShadow(
      color: Color(0x4D50371E),
      blurRadius: 16,
      offset: Offset(0, 8),
      spreadRadius: -10,
    ),
  ];

  /// FAB shadow: 0 16 32 -10 in accentDeep at 55%, built from the palette.
  static List<BoxShadow> fab(MTPalette p) => [
    BoxShadow(
      color: p.accentDeep.withValues(alpha: 0.55),
      blurRadius: 32,
      offset: const Offset(0, 16),
      spreadRadius: -10,
    ),
  ];

  /// A card under the mouse (Windows only): a warm glow lighter than the
  /// resting card's shadow, so hovering reads as a lift, not a jump.
  static List<BoxShadow> hover(MTPalette p) => [
    BoxShadow(
      color: p.accentDeep.withValues(alpha: 0.22),
      blurRadius: 28,
      offset: const Offset(0, 12),
      spreadRadius: -12,
    ),
  ];

  /// Mini player shadow: 0 18 40 -12 in ink at 50%.
  static List<BoxShadow> mini(MTPalette p) => [
    BoxShadow(
      color: p.ink.withValues(alpha: 0.5),
      blurRadius: 40,
      offset: const Offset(0, 18),
      spreadRadius: -12,
    ),
  ];
}
