import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The swaying bars that mark the clip playing in a list, as the library's
/// cover does: on a cover, in a dark round so they read over any picture;
/// in a line of text, on their own. Still while paused.
class NowPlayingBars extends StatelessWidget {
  const NowPlayingBars({super.key, required this.playing, this.onCover = true});

  final bool playing;

  /// Over a cover rather than in a line of text.
  final bool onCover;

  @override
  Widget build(BuildContext context) {
    final bars = ExcludeSemantics(child: MTEqualizer(animate: playing));
    if (!onCover) return bars;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MTPalette.fullscreenScrim.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Padding(padding: const EdgeInsets.all(MTSpace.xxs), child: bars),
    );
  }
}
