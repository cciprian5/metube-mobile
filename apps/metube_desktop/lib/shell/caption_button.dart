import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'shell_metrics.dart';

/// One of the three caption buttons (minimize, maximize, close), drawn as
/// Windows draws its own: the width of a caption button, the height of the
/// bar, and a fill under the pointer.
class CaptionButton extends StatefulWidget {
  const CaptionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.forceHover = false,
  });

  final MTIconData icon;
  final String label;
  final VoidCallback onTap;

  /// The close button turns red under the pointer, as Windows' does.
  final bool danger;
  final bool forceHover;

  @override
  State<CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final lit = _hover || widget.forceHover;
    final fill = !lit ? null : (widget.danger ? p.err : p.cardAlt);
    final ink = lit && widget.danger ? p.bg : p.ink2;
    return Semantics(
      button: true,
      label: widget.label,
      child: MTShortcutTooltip(
        message: widget.label,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: mtMotionDuration(context, MTMotion.fast),
              width: EmberShellSize.captionButton,
              height: EmberShellSize.titleBar,
              color: fill ?? p.bg,
              alignment: Alignment.center,
              child: MTIcon(widget.icon, size: MTSpace.lg, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}
