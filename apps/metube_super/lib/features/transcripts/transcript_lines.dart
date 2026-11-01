import 'package:flutter/material.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import 'transcript_moment.dart';

/// Every line of one transcript, built lazily: a two-hour talk holds
/// thousands of lines, and only the dozen on screen are ever built.
///
/// Can bring a line into view, whether built or not, and keep the line
/// being said in view as playback moves, except while the reader is
/// scrolling on their own.
class TranscriptLines extends StatefulWidget {
  const TranscriptLines({
    super.key,
    required this.segments,
    required this.query,
    required this.controller,
    required this.onMoment,
    this.following = false,
    this.now,
    this.opening,
    this.onQuote,
    this.quote,
  });

  final List<TranscriptSegment> segments;
  final String query;
  final ScrollController controller;
  final void Function(Duration start) onMoment;

  /// Marks the line being said, [now].
  final bool following;
  final int? now;

  /// Brought into view when the list first shows.
  final int? opening;

  /// A long press on line i starts a quote there; while [quote] is made, a
  /// tap on a line takes it in instead of playing from it.
  final void Function(int index, {required bool longPress})? onQuote;
  final ({int first, int last})? quote;

  /// The line being said at [position]: the last one begun by then. Null
  /// before the first.
  static int? lineAt(List<TranscriptSegment> segments, Duration position) =>
      segmentAt(segments, position);

  @override
  State<TranscriptLines> createState() => TranscriptLinesState();
}

class TranscriptLinesState extends State<TranscriptLines> {
  final _target = GlobalKey();
  int? _targetIndex;
  DateTime _touched = DateTime.fromMillisecondsSinceEpoch(0);

  /// How long a reader's own scrolling holds off following playback.
  static const handsOff = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    if (widget.opening case final line?) {
      _targetIndex = line;
      _afterFrame(line, animate: false);
    }
  }

  /// Brings [index] into view now.
  void reveal(int index) => _goTo(index, animate: false);

  /// Brings [index] into view gently, unless the reader is scrolling.
  void follow(int index) {
    if (DateTime.now().difference(_touched) < handsOff) return;
    _goTo(index, animate: true);
  }

  void _goTo(int index, {required bool animate}) {
    if (index < 0 || index >= widget.segments.length) return;
    setState(() => _targetIndex = index);
    _afterFrame(index, animate: animate);
  }

  void _afterFrame(int index, {required bool animate, int tries = 3}) =>
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _settle(index, animate: animate, tries: tries),
      );

  /// A line not built yet has no place to scroll to: jump to where it
  /// should be, going by the lines so far, then finish on the real one.
  void _settle(int index, {required bool animate, required int tries}) {
    if (!mounted || _targetIndex != index) return;
    final target = _target.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
      );
      return;
    }
    final scroll = widget.controller;
    if (tries == 0 || !scroll.hasClients) return;
    final position = scroll.position;
    final length = position.maxScrollExtent + position.viewportDimension;
    final guess =
        length * index / widget.segments.length -
        position.viewportDimension * 0.3;
    scroll.jumpTo(guess.clamp(0.0, position.maxScrollExtent));
    _afterFrame(index, animate: animate, tries: tries - 1);
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (event) {
          if (event.dragDetails != null) _touched = DateTime.now();
          return false;
        },
        child: ListView.builder(
          controller: widget.controller,
          itemCount: widget.segments.length,
          itemBuilder: (context, i) {
            final segment = widget.segments[i];
            final quote = widget.quote;
            final onQuote = widget.onQuote;
            return TranscriptMomentRow(
              key: i == _targetIndex ? _target : null,
              start: segment.start,
              text: segment.text,
              query: widget.query,
              maxLines: null,
              current: widget.following ? i == widget.now : null,
              quoted: quote != null && i >= quote.first && i <= quote.last,
              onTap: quote != null && onQuote != null
                  ? () => onQuote(i, longPress: false)
                  : () => widget.onMoment(segment.start),
              onLongPress: onQuote == null
                  ? null
                  : () => onQuote(i, longPress: true),
            );
          },
        ),
      );
}
