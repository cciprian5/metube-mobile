import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../widgets/mt_polish.dart';

/// Waiting without a known end: a hairline ring with a gap, turning, the
/// ember riding the head of the arc. Stands still when the system asks for
/// less motion; the ring and the ember still say "working".
class MTSpinner extends StatefulWidget {
  const MTSpinner({super.key, this.size = 34, this.semanticLabel});

  final double size;

  /// What is being waited for, read by screen readers.
  final String? semanticLabel;

  @override
  State<MTSpinner> createState() => _MTSpinnerState();
}

class _MTSpinnerState extends State<MTSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _turn.stop() : _turn.repeat();
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: RotationTransition(
        turns: CurvedAnimation(
          parent: _turn,
          curve: const Cubic(0.5, 0.1, 0.5, 0.9),
        ),
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _RingPainter(track: p.line2, arc: p.ink2, ember: p.accent),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.track, required this.arc, required this.ember});

  final Color track;
  final Color arc;
  final Color ember;

  /// The share of the ring the arc covers; the rest is the gap.
  static const _sweep = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 34;
    final c = size.center(Offset.zero);
    final r = 13 * scale;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, line..color = track);
    // The arc ends at the top, where the ember sits on its head.
    const head = -math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      head - _sweep * 2 * math.pi,
      _sweep * 2 * math.pi,
      false,
      line..color = arc,
    );
    canvas.drawCircle(c + Offset(0, -r), 2.6 * scale, Paint()..color = ember);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.track != track || old.arc != arc || old.ember != ember;
}

/// A known amount: a 2-point line led by the ember. It fills from the start
/// of the reading direction, like the playback bar.
class MTProgressBar extends StatelessWidget {
  const MTProgressBar({super.key, required this.value});

  /// From 0 to 1; out-of-range values are clamped.
  final double value;

  static const _line = 2.0;
  static const _ember = 6.0;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(v * 100).round()}%',
      child: SizedBox(
        height: _ember + 6,
        child: LayoutBuilder(
          builder: (context, box) {
            final filled = box.maxWidth * v;
            return Stack(
              alignment: AlignmentDirectional.centerStart,
              clipBehavior: Clip.none,
              children: [
                Container(height: _line, color: p.line2),
                AnimatedContainer(
                  duration: mtMotionDuration(context, MTMotion.fast),
                  width: filled,
                  height: _line,
                  color: p.accent,
                ),
                AnimatedPositionedDirectional(
                  duration: mtMotionDuration(context, MTMotion.fast),
                  start: filled - _ember / 2,
                  child: Container(
                    key: const ValueKey('ember'),
                    width: _ember,
                    height: _ember,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accent,
                      boxShadow: [
                        BoxShadow(
                          color: p.accent.withValues(alpha: 0.2),
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Waiting with no measure at all: film perforations sliding by in the
/// reading direction.
class MTFilmStrip extends StatefulWidget {
  const MTFilmStrip({super.key});

  @override
  State<MTFilmStrip> createState() => _MTFilmStripState();
}

class _MTFilmStripState extends State<MTFilmStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _slide.stop() : _slide.repeat();
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MTCorners.desktop.box / 3),
        child: AnimatedBuilder(
          animation: _slide,
          builder: (context, _) => CustomPaint(
            painter: _PerforationPainter(
              color: p.ink3.withValues(alpha: 0.55),
              shift: (rtl ? -1 : 1) * _slide.value,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  _PerforationPainter({required this.color, required this.shift});

  final Color color;

  /// The fraction of one period moved, signed by the direction of travel.
  final double shift;

  static const _hole = 8.0;
  static const _period = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = -_period + shift * _period; x < size.width; x += _period) {
      canvas.drawRect(Rect.fromLTWH(x, 0, _hole, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.shift != shift || old.color != color;
}
