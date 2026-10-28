import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The swaying bars that mark the clip playing in a list, at the line's
/// end after its title, where the phone's card puts them. Still while
/// paused.
class NowPlayingBars extends StatelessWidget {
  const NowPlayingBars({super.key, required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: MTEqualizer(animate: playing));
}
