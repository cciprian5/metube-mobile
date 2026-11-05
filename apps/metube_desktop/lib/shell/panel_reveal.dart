import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The side panel, **opened and closed in place**: its room widens at the
/// pace of an entrance while what is in it fades in and slides the last few
/// points from its edge; it closes quicker than it opens. Shown or hidden in
/// one frame, the content beside it jumped by a panel's width.
///
/// The child keeps its own width; only the room it is given changes, so
/// nothing inside the panel is laid out again while it moves.
class PanelReveal extends StatefulWidget {
  const PanelReveal({super.key, required this.shown, required this.child});

  final bool shown;
  final Widget child;

  /// How far the content slides in from the panel's outer edge.
  static const double nudge = MTSpace.xs;

  @override
  State<PanelReveal> createState() => _PanelRevealState();
}

class _PanelRevealState extends State<PanelReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    value: widget.shown ? 1 : 0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion
      ..duration = mtMotionDuration(context, MTMotion.medium)
      ..reverseDuration = mtMotionDuration(context, MTMotion.fast);
  }

  @override
  void didUpdateWidget(PanelReveal old) {
    super.didUpdateWidget(old);
    if (old.shown == widget.shown) return;
    if (widget.shown) {
      _motion.forward();
    } else {
      _motion.reverse();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _motion,
      child: widget.child,
      builder: (context, child) {
        if (_motion.value == 0) return const SizedBox.shrink();
        // In on the entrance curve; out on the exit curve run from the
        // closing's own start, so it gathers speed as it leaves.
        final v = _motion.value;
        final t = _motion.status == AnimationStatus.reverse
            ? 1 - MTMotion.exit.transform(1 - v)
            : MTMotion.entrance.transform(v);
        final slide = PanelReveal.nudge * (1 - t) * (rtl ? -1 : 1);
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: t,
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(slide, 0),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The side panel over the content, in a window too narrow to set it
/// beside: a click anywhere else closes it, and it opens and closes in
/// motion as the panel beside does. Children of the content's stack.
List<Widget> overlayPanel({
  required bool open,
  required VoidCallback onClose,
  required Widget panel,
}) => [
  if (open)
    Positioned.fill(
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose),
    ),
  PositionedDirectional(
    top: 0,
    bottom: 0,
    end: 0,
    child: PanelReveal(
      shown: open,
      child: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: MTShadow.card),
        child: panel,
      ),
    ),
  ),
];
