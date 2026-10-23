import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../widgets/mt_desktop_app.dart';
import '../widgets/mt_polish.dart';

/// A card that rises under the mouse: a warm glow beneath it and a small
/// lift, and [builder] learns it is hovered (to show a play mark, say).
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
    final duration = mtMotionDuration(context, MTMotion.fast);
    return MouseRegion(
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: AnimatedContainer(
        duration: duration,
        curve: MTMotion.ease,
        transform: Matrix4.translationValues(
          0,
          _hovered ? -MTSpace.xxs / 2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: _hovered ? MTShadow.hover(p) : const [],
        ),
        child: widget.builder(context, _hovered),
      ),
    );
  }
}
