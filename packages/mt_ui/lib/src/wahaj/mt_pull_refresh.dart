import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../widgets/mt_polish.dart';
import 'mt_progress.dart';

/// Pull to refresh with the Wahaj ring: the ring with its gap and ember
/// at the top of the list, turning while the refresh runs, with no floating
/// disc beneath it. Faint while the pull has not yet gone far enough, whole
/// once letting go would refresh.
class MTPullRefresh extends StatefulWidget {
  const MTPullRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.semanticsLabel,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final String? semanticsLabel;

  @override
  State<MTPullRefresh> createState() => _MTPullRefreshState();
}

class _MTPullRefreshState extends State<MTPullRefresh> {
  RefreshIndicatorStatus? _status;

  double get _opacity => switch (_status) {
    RefreshIndicatorStatus.drag => 0.45,
    RefreshIndicatorStatus.armed ||
    RefreshIndicatorStatus.snap ||
    RefreshIndicatorStatus.refresh => 1,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      RefreshIndicator.noSpinner(
        onRefresh: widget.onRefresh,
        semanticsLabel: widget.semanticsLabel,
        onStatusChange: (status) {
          if (mounted) setState(() => _status = status);
        },
        child: widget.child,
      ),
      PositionedDirectional(
        top: MTSpace.md,
        start: 0,
        end: 0,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: mtMotionDuration(context, MTMotion.tap),
            // Hidden, the ring stops turning rather than spin unseen.
            child: TickerMode(
              enabled: _opacity > 0,
              child: Center(
                // A flat patch of the ground under the ring, no shadow and
                // no lift: over a chip's label the bare ring blurred into
                // the letters.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MTThemeX.of(context).palette.bg,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(MTSpace.xs + 2),
                    child: MTSpinner(size: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
