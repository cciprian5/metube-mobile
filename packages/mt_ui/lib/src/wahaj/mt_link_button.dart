import 'package:flutter/material.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icon_data.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// An action written as a link rather than a filled button: bold text in
/// the accent, and **a line drawn beneath it while pressed or hovered**,
/// growing from the start of the reading direction. Used where a filled
/// button would shout, such as the one way out of an empty screen.
class MTLinkButton extends StatefulWidget {
  const MTLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final MTIconData? icon;

  @override
  State<MTLinkButton> createState() => _MTLinkButtonState();
}

class _MTLinkButtonState extends State<MTLinkButton> {
  bool _hot = false;

  void _set(bool v) {
    if (_hot != v) setState(() => _hot = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final enabled = widget.onPressed != null;
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: p.accentInk);
    return Semantics(
      button: true,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: _set,
        onShowFocusHighlight: _set,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed?.call(),
          ),
        },
        child: GestureDetector(
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          onTap: widget.onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _hot ? 1 : 0),
              duration: MTMotion.fast,
              curve: MTMotion.ease,
              builder: (context, drawn, child) => CustomPaint(
                key: const ValueKey('underline'),
                foregroundPainter: _UnderlinePainter(
                  drawn: drawn,
                  color: p.accent,
                  rtl: Directionality.of(context) == TextDirection.rtl,
                ),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      MTIcon(widget.icon!, size: 16, color: p.accentInk),
                      const SizedBox(width: MTSpace.xxs),
                    ],
                    // Ellipsized when the space is narrower than the label
                    // (a large text size in a narrow pane), never spilled.
                    Flexible(
                      child: Text(
                        widget.label,
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The line under the link: [drawn] of the full width, growing from the
/// start of the reading direction.
class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter({
    required this.drawn,
    required this.color,
    required this.rtl,
  });

  final double drawn;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawn <= 0) return;
    final w = size.width * drawn;
    final left = rtl ? size.width - w : 0.0;
    canvas.drawRect(
      Rect.fromLTWH(left, size.height - 1.5, w, 1.5),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) =>
      old.drawn != drawn || old.color != color || old.rtl != rtl;
}
