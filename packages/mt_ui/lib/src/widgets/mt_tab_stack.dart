import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// The shell's sections, kept alive side by side as an `IndexedStack`
/// keeps them, with **a short fade between them**: the section left goes
/// first, then the one chosen comes in. No slide, since sections are
/// places side by side rather than steps. An `IndexedStack` cut from one
/// to the other in a single frame.
class MTTabStack extends StatefulWidget {
  const MTTabStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<MTTabStack> createState() => _MTTabStackState();
}

class _MTTabStackState extends State<MTTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: MTMotion.fast * 2,
    value: 1,
  )..addStatusListener(_settled);

  // Only the last of several quick switches clears the one fading out.
  void _settled(AnimationStatus status) {
    if (status.isCompleted && _leaving != null && mounted) {
      setState(() => _leaving = null);
    }
  }

  /// The section fading out, while it does.
  int? _leaving;

  @override
  void didUpdateWidget(MTTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _leaving = null;
      _fade.value = 1;
      return;
    }
    _leaving = oldWidget.index;
    _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _fade,
    builder: (context, _) {
      final t = _fade.value;
      final leaving = _leaving;
      final out = leaving == null
          ? 0.0
          : 1 - MTMotion.exit.transform((t * 2).clamp(0.0, 1.0));
      final shown = leaving == null
          ? 1.0
          : MTMotion.entrance.transform((t * 2 - 1).clamp(0.0, 1.0));
      return Stack(
        fit: StackFit.expand,
        children: [
          for (final (i, child) in widget.children.indexed)
            Offstage(
              offstage: i != widget.index && i != leaving,
              child: TickerMode(
                enabled: i == widget.index,
                child: IgnorePointer(
                  ignoring: i != widget.index,
                  child: Opacity(
                    opacity: i == widget.index ? shown : out,
                    child: child,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
