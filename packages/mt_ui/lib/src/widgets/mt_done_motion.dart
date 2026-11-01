import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'mt_polish.dart';

/// A check that **draws itself** as it appears: the moment a download
/// finishes, where the card used to vanish without a word.
class MTDrawnCheck extends StatelessWidget {
  const MTDrawnCheck({super.key, required this.color, this.size = 22});

  final Color color;
  final double size;

  /// Long enough to be seen drawn, as a success should be.
  static const Duration draw = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: mtMotionDuration(context, draw),
    curve: MTMotion.entrance,
    builder: (context, t, _) => Opacity(
      opacity: (t * 3).clamp(0.0, 1.0),
      child: CustomPaint(
        size: Size.square(size),
        painter: _Check(color: color, drawn: t),
      ),
    ),
  );
}

class _Check extends CustomPainter {
  const _Check({required this.color, required this.drawn});

  final Color color;
  final double drawn;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.2, s * 0.53)
      ..lineTo(s * 0.42, s * 0.74)
      ..lineTo(s * 0.8, s * 0.3);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * drawn), paint);
    }
  }

  @override
  bool shouldRepaint(_Check old) => old.drawn != drawn || old.color != color;
}

/// A row that has done its work: it stays for [linger], then **folds
/// away** and fades, and tells its list it is gone, so the rows under it
/// close the gap instead of jumping up.
class MTFoldAway extends StatefulWidget {
  const MTFoldAway({
    super.key,
    required this.child,
    required this.onGone,
    this.linger = MTDrawnCheck.draw,
  });

  final Widget child;
  final VoidCallback onGone;
  final Duration linger;

  @override
  State<MTFoldAway> createState() => _MTFoldAwayState();
}

class _MTFoldAwayState extends State<MTFoldAway>
    with SingleTickerProviderStateMixin {
  // One run for both the stay and the fold: no timer outlives the row.
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: widget.linger + MTMotion.medium,
  );
  late final Animation<double> _left = ReverseAnimation(
    CurvedAnimation(
      parent: _run,
      curve: Interval(
        widget.linger.inMicroseconds / _run.duration!.inMicroseconds,
        1,
        curve: MTMotion.exit,
      ),
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_run.isAnimating || _run.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onGone();
      });
      return;
    }
    _run.forward().whenComplete(() {
      if (mounted) widget.onGone();
    });
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _left,
    alignment: Alignment.topCenter,
    child: FadeTransition(opacity: _left, child: widget.child),
  );
}
