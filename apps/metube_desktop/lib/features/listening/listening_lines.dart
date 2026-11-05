import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The transcript flowing past** in the listening room: large lines, the
/// one being said in ink and held a little above the middle, the rest
/// faint and fading out at both edges. A click on a line plays from it.
///
/// Not for reading (that is the reading room): it scrolls only with the
/// sound, so nothing pulls against it.
class ListeningLines extends StatefulWidget {
  const ListeningLines({
    super.key,
    required this.segments,
    required this.player,
  });

  final List<TranscriptSegment> segments;
  final MTPlayer player;

  @override
  State<ListeningLines> createState() => _ListeningLinesState();
}

class _ListeningLinesState extends State<ListeningLines> {
  late List<GlobalKey> _keys = _keysFor(widget.segments);
  StreamSubscription<Duration>? _positions;
  int? _now;

  /// The first line is placed without moving: the room opens on it.
  var _placed = false;

  /// Where the line being said sits, from the top.
  static const _hold = 0.4;

  static List<GlobalKey> _keysFor(List<TranscriptSegment> segments) => [
    for (final _ in segments) GlobalKey(),
  ];

  @override
  void initState() {
    super.initState();
    _show(widget.player.position);
    _positions = widget.player.positionStream.listen(_show);
  }

  @override
  void didUpdateWidget(ListeningLines old) {
    super.didUpdateWidget(old);
    if (old.segments != widget.segments) {
      _keys = _keysFor(widget.segments);
      _now = null;
      _placed = false;
      _show(widget.player.position);
    }
  }

  @override
  void dispose() {
    unawaited(_positions?.cancel());
    super.dispose();
  }

  void _show(Duration position) {
    final now = segmentAt(widget.segments, position);
    if (now == _now || !mounted) return;
    setState(() => _now = now);
    if (now == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[now].currentContext;
      if (target == null || !target.mounted) return;
      final glide = _placed
          ? mtMotionDuration(context, MTMotion.slow)
          : Duration.zero;
      _placed = true;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: _hold,
          duration: glide,
          curve: MTMotion.ease,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final style = Theme.of(context).textTheme.headlineSmall;
    final segments = widget.segments;
    return LayoutBuilder(
      builder: (context, box) => ShaderMask(
        // Lines fade in at the foot and out at the head, so the text seems
        // to pass rather than be cut off. A mask over the text alone: a
        // fade painted in the room's colour would cover the embers too.
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // A mask, not a colour: only how opaque each stop is counts.
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, 0.22, 0.78, 1],
        ).createShader(rect),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          // Room above the first line and below the last, so either can
          // sit where the line being said is held.
          padding: EdgeInsets.symmetric(vertical: box.maxHeight * 0.5),
          // One layer for all the lines: gliding moves it and repaints
          // nothing.
          child: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < segments.length; i++)
                  GestureDetector(
                    key: _keys[i],
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        unawaited(widget.player.seek(segments[i].start)),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: MTSpace.sm,
                        ),
                        child: Text(
                          segments[i].text,
                          textDirection: mtTextDirectionOf(
                            segments[i].text,
                            Directionality.of(context),
                          ),
                          style: style?.copyWith(
                            color: i == _now ? p.ink : p.ink3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
