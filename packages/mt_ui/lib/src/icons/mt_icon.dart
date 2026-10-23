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
  });

  final MTIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

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
    final ember = MTThemeX.of(context).palette.accent;
    return icon.paint(ink: _hex(ink), ember: _hex(ember));
  }

  @override
  Widget build(BuildContext context) {
    final side = size ?? IconTheme.of(context).size ?? 24;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: SvgPicture.string(svgIn(context), width: side, height: side),
    );
  }
}
