import 'package:flutter/material.dart';

import '../theme/mt_theme_controls.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../widgets/mt_desktop_app.dart';
import '../widgets/mt_polish.dart';

/// A card that answers the mouse: **a plate a shade darker than the page
/// appears behind it**, reaching a little past its edges, and [builder]
/// learns it is hovered (to show a play mark, say). It does not rise and
/// does not glow: a lift with a warm shadow under every card is one of the
/// marks of a generated screen, and the file explorer's plate says the
/// same thing quietly.
///
/// **Windows only.** Outside [MTDesktopApp] it builds the child as it was,
/// never hovered, so a phone or a tablet with a mouse looks the same as
/// before.
class MTHoverLift extends StatefulWidget {
  const MTHoverLift({
    super.key,
    required this.borderRadius,
    required this.builder,
  });

  final BorderRadius borderRadius;

  /// How far the plate reaches past the card on every side.
  static const double reach = MTSpace.xs;
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<MTHoverLift> createState() => _MTHoverLiftState();
}

class _MTHoverLiftState extends State<MTHoverLift> {
  bool _hovered = false;

  void _hover(bool on) {
    if (on != _hovered) setState(() => _hovered = on);
  }

  @override
  Widget build(BuildContext context) {
    if (!MTDesktopApp.isDesktop(context)) {
      return widget.builder(context, false);
    }
    final p = MTThemeX.of(context).palette;
    return MouseRegion(
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: -MTHoverLift.reach,
            top: -MTHoverLift.reach,
            right: -MTHoverLift.reach,
            bottom: -MTHoverLift.reach,
            child: AnimatedContainer(
              key: const ValueKey('hover-plate'),
              duration: mtMotionDuration(context, MTMotion.fast),
              curve: MTMotion.ease,
              decoration: BoxDecoration(
                color: _hovered
                    ? p.ink.withValues(alpha: mtHoverVeil)
                    : p.ink.withValues(alpha: 0),
                borderRadius: widget.borderRadius,
              ),
            ),
          ),
          widget.builder(context, _hovered),
        ],
      ),
    );
  }
}
