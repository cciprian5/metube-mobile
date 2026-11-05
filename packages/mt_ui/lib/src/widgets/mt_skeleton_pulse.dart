import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// A skeleton's slow breath while the first answer is on the way, as the
/// big apps do (owner's request 2026-11-05: a still placeholder read as a
/// frozen screen). The whole placeholder dims and brightens together; no
/// light sweeps across it, which is the generated-screen mark the still
/// skeleton was avoiding.
///
/// It stops by itself after [breaths], fully bright: a skeleton still up
/// by then is a slow server, and a placeholder that never stops moving is
/// one a test, or a tired eye, never sees settle. With animations turned
/// off in the system it never moves.
class MTSkeletonPulse extends StatefulWidget {
  const MTSkeletonPulse({super.key, required this.child, this.breaths = 12});

  final Widget child;
  final int breaths;

  /// How far down a breath dims the placeholder.
  static const double dimmest = 0.45;

  @override
  State<MTSkeletonPulse> createState() => _MTSkeletonPulseState();
}

class _MTSkeletonPulseState extends State<MTSkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: MTMotion.wait,
    value: 1,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: MTSkeletonPulse.dimmest,
    end: 1,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_breath);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = 1;
    } else if (!_breath.isAnimating && _breath.value == 1) {
      // Down and back up is one breath; it ends where it began, bright.
      _breath
          .repeat(reverse: true, count: widget.breaths * 2)
          .whenCompleteOrCancel(() {
            if (mounted) _breath.value = 1;
          });
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}
