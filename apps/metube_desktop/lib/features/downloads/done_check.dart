import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The copy has arrived**: a check in the colour of things done, drawn
/// once as it appears, a stroke following the pen after a short beat. A
/// line that only changed its words was easy to miss; this says the app
/// did what it was asked. Drawn whole at once for anyone who turned
/// animations off.
class DoneCheck extends StatelessWidget {
  const DoneCheck({super.key, this.size = MTSpace.lg});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: mtMotionDuration(context, _draw),
      curve: MTMotion.entrance,
      builder: (context, drawn, _) => Opacity(
        opacity: (drawn * 3).clamp(0, 1),
        child: CustomPaint(
          size: Size.square(size),
          painter: _CheckPainter(drawn: drawn, color: p.ok),
        ),
      ),
    );
  }

  /// How long the stroke takes to draw.
  static const _draw = Duration(milliseconds: 500);
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.drawn, required this.color});

  final double drawn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(6 * s, 12.5 * s)
      ..lineTo(10 * s, 16.5 * s)
      ..lineTo(18 * s, 7.5 * s);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final PathMetric metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * drawn), pen);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.drawn != drawn || old.color != color;
}
