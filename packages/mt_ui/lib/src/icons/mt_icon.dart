import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/mt_theme.dart';
import 'mt_icon_data.dart';

/// Draws a Wahaj icon the way `Icon` draws a glyph: colour and size from the
/// surrounding [IconTheme], so it drops into a button unchanged. The ember
/// mark always takes the palette's accent, which is what keeps the icon in
/// step with day, night and the app's own colour.
class MTIcon extends StatelessWidget {
  const MTIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.matchTextDirection = false,
    this.shadows,
  });

  final MTIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  /// Mirrored when the text runs right to left: for the arrows that point
  /// along the reading direction (back, forward, a row's chevron), as
  /// `Icon` mirrors them. Nothing else turns, as in the Windows app.
  final bool matchTextDirection;

  /// Drawn beneath the icon, blurred, as `Icon` draws its glyph's shadows:
  /// what keeps an icon legible over a cover of unknown colour.
  final List<Shadow>? shadows;

  static String _hex(Color c) {
    final argb = c.toARGB32();
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final alpha = (argb >> 24) & 0xFF;
    return alpha == 0xFF
        ? '#$rgb'
        : '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
  }

  /// The SVG as it is drawn here: the ink from [color] or the icon theme,
  /// the ember from the palette.
  @visibleForTesting
  String svgIn(BuildContext context) {
    final ink = color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    // Outside a Wahaj theme (a bare widget in a test) the ember takes the
    // ink, as Material's glyph draws without a theme.
    final ember =
        Theme.of(context).extension<MTThemeX>()?.palette.accent ?? ink;
    return icon.paint(ink: _hex(ink), ember: _hex(ember));
  }

  @override
  Widget build(BuildContext context) {
    final side = size ?? IconTheme.of(context).size ?? 24;
    Widget glyph = SvgPicture.string(svgIn(context), width: side, height: side);
    if (shadows case final shadows? when shadows.isNotEmpty) {
      glyph = Stack(
        clipBehavior: Clip.none,
        children: [
          for (final s in shadows)
            Transform.translate(
              offset: s.offset,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: s.blurSigma,
                  sigmaY: s.blurSigma,
                ),
                child: SvgPicture.string(
                  icon.paint(ink: _hex(s.color), ember: _hex(s.color)),
                  width: side,
                  height: side,
                ),
              ),
            ),
          glyph,
        ],
      );
    }
    if (matchTextDirection &&
        Directionality.maybeOf(context) == TextDirection.rtl) {
      glyph = Transform.flip(flipX: true, child: glyph);
    }
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: glyph,
    );
  }
}
