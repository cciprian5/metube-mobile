import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's mark (E3, a window whose title bar glows) on its espresso
/// tile, from the brand files `tool/icons/ember_kit.py` draws: one source
/// for the Windows icon, the tray and the app itself.
///
/// Below [smallBelow] points the small cut is drawn, as the icon is:
/// without the perforations, which blur into a smudge there. Both carry a
/// faint cream rim, so the dark tile does not melt into the night theme.
class EmberMark extends StatelessWidget {
  const EmberMark({super.key, required this.size});

  final double size;

  static const smallBelow = 24.0;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      size < smallBelow
          ? 'brand/ember-symbol-small.svg'
          : 'brand/ember-symbol-dark.svg',
      width: size,
      height: size,
    ),
  );
}
