import 'package:flutter/material.dart';

import '../icons/mt_icon_data.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_link_button.dart';

/// The Wahaj empty screen: a line drawing from the identity (an empty film
/// frame with the ember waiting in it) instead of an icon in a coloured
/// circle; a plain title that names what is empty; one sentence that says
/// **how to begin**; and the way out as a link, not a filled button.
class MTEmptyFrame extends StatelessWidget {
  const MTEmptyFrame({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final MTIconData? actionIcon;
  final VoidCallback? onAction;

  static const _art = Size(132, 84);
  static const _textWidth = 260.0;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: _art,
          painter: _FramePainter(line: p.ink3, holes: p.line2, ember: p.accent),
        ),
        const SizedBox(height: MTSpace.md),
        Text(title, style: text.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: MTSpace.xxs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _textWidth),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: p.ink3),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: MTSpace.xs),
          MTLinkButton(
            label: actionLabel!,
            icon: actionIcon,
            onPressed: onAction,
          ),
        ],
      ],
    );
  }
}

/// The frame from the mockup's 132x84 drawing, scaled to the given size.
class _FramePainter extends CustomPainter {
  _FramePainter({required this.line, required this.holes, required this.ember});

  final Color line;
  final Color holes;
  final Color ember;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 132, size.height / 84);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = line;
    // The frame's edge, dashed six on six.
    final edge = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(10, 8, 112, 68),
          const Radius.circular(8),
        ),
      );
    for (final metric in edge.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), stroke);
      }
    }
    // Perforations along the top and bottom.
    final hole = Paint()..color = holes;
    for (var x = 18.0; x <= 108; x += 15) {
      for (final y in [13.0, 66.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 7, 5),
            const Radius.circular(1.5),
          ),
          hole,
        );
      }
    }
    // The ember, waiting, with a faint ring.
    const centre = Offset(66, 42);
    canvas.drawCircle(centre, 4.5, Paint()..color = ember);
    canvas.drawCircle(
      centre,
      10,
      stroke..color = ember.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.line != line || old.holes != holes || old.ember != ember;
}
