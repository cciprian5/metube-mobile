import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// What the window shows while links are dragged over it: a dashed frame
/// in the action colour around the content, on a soft wash, saying what
/// letting go does. The frame is drawn like the empty screens' film frame,
/// so it reads as a place to put something.
class DropFrame extends StatelessWidget {
  const DropFrame({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final radius = MTCorners.desktop.card;
    return Padding(
      padding: const EdgeInsets.all(MTSpace.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dropWash(p),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: CustomPaint(
          foregroundPainter: DashedEdge(color: p.accent, radius: radius),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: p.accentInk),
            ),
          ),
        ),
      ),
    );
  }
}

/// The wash over the window: the soft accent as it looks on the ground,
/// then let through a little. The night's soft accent is itself see-through,
/// so giving it an opacity of its own, as the day's takes, turned the whole
/// window a glaring orange with the words lost in it.
Color dropWash(MTPalette p) =>
    Color.alphaBlend(p.accentSoft, p.bg).withValues(alpha: 0.9);

/// A rounded edge dashed [dash] on [gap].
class DashedEdge extends CustomPainter {
  const DashedEdge({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const dash = 10.0;
  static const gap = 7.0;
  static const width = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    final inset = (Offset.zero & size).deflate(width / 2);
    final edge = Path()
      ..addRRect(RRect.fromRectAndRadius(inset, Radius.circular(radius)));
    for (final metric in edge.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(DashedEdge old) =>
      old.color != color || old.radius != radius;
}
