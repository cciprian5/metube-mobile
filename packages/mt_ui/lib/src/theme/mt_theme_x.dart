import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// Theme extension: carries the Wahaj palette to every widget through
/// `MTThemeX.of(context)` instead of any literal colour (rule 5).
class MTThemeX extends ThemeExtension<MTThemeX> {
  const MTThemeX({
    required this.palette,
    required this.variant,
    this.hairline = 1,
  });

  final MTPalette palette;
  final MTVariant variant;

  /// How thick a hairline (a border, a rule) is drawn: one pixel, or more
  /// where the user asked the system for high contrast.
  final double hairline;

  static MTThemeX of(BuildContext context) =>
      Theme.of(context).extension<MTThemeX>()!;

  @override
  MTThemeX copyWith({
    MTPalette? palette,
    MTVariant? variant,
    double? hairline,
  }) => MTThemeX(
    palette: palette ?? this.palette,
    variant: variant ?? this.variant,
    hairline: hairline ?? this.hairline,
  );

  @override
  MTThemeX lerp(MTThemeX? other, double t) => t < 0.5 ? this : other ?? this;
}
