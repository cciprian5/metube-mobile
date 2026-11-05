import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/transcripts_data.dart';
import '../../features/reading/reading_find.dart';
import '../../features/reading/reading_room.dart';
import 'transcript_line.dart';

/// Where Ctrl+F goes while the side panel shows a transcript: its find
/// bar. The reading room's own comes first; elsewhere the window's search.
final panelFindProvider = Provider<ValueNotifier<VoidCallback?>>((ref) {
  final hook = ValueNotifier<VoidCallback?>(null);
  ref.onDispose(hook.dispose);
  return hook;
});

/// What Ctrl+F finds in: the reading room's text, else the side panel's
/// transcript; null leaves it to the window's search.
VoidCallback? findHere(WidgetRef ref) =>
    ref.read(readingFindProvider).value ?? ref.read(panelFindProvider).value;

/// The playing clip's transcript, lighting the line being said and keeping
/// it in view; a click on a line plays from there.
class TranscriptView extends ConsumerWidget {
  const TranscriptView({super.key, required this.item, required this.player});

  final PlaylistItem item;
  final MTPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final transcript = ref.watch(
      transcriptForProvider((
        canonicalUrl: item.canonicalUrl,
        serverFilename: item.serverFilename,
      )),
    );
    return switch (transcript) {
      AsyncData(value: final t?) when !t.isEmpty => _Lines(
        key: ValueKey(item.canonicalUrl),
        segments: t.segments,
        player: player,
        findHook: ref.read(panelFindProvider),
      ),
      AsyncLoading() => const Center(child: MTSpinner()),
      _ => Center(
        child: SingleChildScrollView(
          child: MTEmptyFrame(
            title: l.desktopNoTranscriptTitle,
            message: l.desktopNoTranscriptMessage,
          ),
        ),
      ),
    };
  }
}

class _Lines extends StatefulWidget {
  const _Lines({
    super.key,
    required this.segments,
    required this.player,
    required this.findHook,
  });

  final List<TranscriptSegment> segments;
  final MTPlayer player;
  final ValueNotifier<VoidCallback?> findHook;

  @override
  State<_Lines> createState() => _LinesState();
}

class _LinesState extends State<_Lines> {
  final _current = GlobalKey();
  StreamSubscription<Duration>? _positions;
  int? _now;

  /// When the user last scrolled by hand. Following waits a moment after
  /// it, so reading back up is not yanked down to the line being said.
  DateTime _scrolledByHand = DateTime.fromMillisecondsSinceEpoch(0);
  static const _handPause = Duration(seconds: 4);

  final _query = TextEditingController();
  final _findFocus = FocusNode();
  final _found = GlobalKey();
  var _finding = false;
  List<FindHit> _hits = const [];
  var _hit = 0;

  @override
  void initState() {
    super.initState();
    _show(widget.player.position);
    _positions = widget.player.positionStream.listen(_show);
    widget.findHook.value = _openFind;
  }

  @override
  void dispose() {
    unawaited(_positions?.cancel());
    if (widget.findHook.value == _openFind) widget.findHook.value = null;
    _query.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  void _openFind() {
    setState(() => _finding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _findFocus.requestFocus();
      _query.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _query.text.length,
      );
    });
  }

  void _closeFind() => setState(() {
    _finding = false;
    _hits = const [];
    _query.clear();
  });

  void _search() {
    setState(() {
      _hits = findIn(widget.segments, _query.text);
      _hit = 0;
    });
    _reveal();
  }

  void _step(int by) {
    if (_hits.isEmpty) return;
    setState(() => _hit = (_hit + by) % _hits.length);
    _reveal();
  }

  /// Brings the chosen place into view; following the voice waits while
  /// the user is finding.
  void _reveal() {
    if (_hits.isEmpty) return;
    _scrolledByHand = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _found.currentContext;
      if (target == null || !target.mounted) return;
      unawaited(Scrollable.ensureVisible(target, alignment: 0.3));
    });
  }

  void _show(Duration position) {
    final now = segmentAt(widget.segments, position);
    if (now == _now || !mounted) return;
    setState(() => _now = now);
    if (_finding || DateTime.now().difference(_scrolledByHand) < _handPause) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _current.currentContext;
      if (target == null || !target.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: mtMotionDuration(context, MTMotion.medium),
          curve: MTMotion.ease,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final chosen = _hits.isEmpty ? null : _hits[_hit];
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At most a third of the panel, so in a short window with large
          // text the hint is clipped rather than pushing the lines out. Not
          // a Flexible: beside the Expanded below it would halve the list.
          if (_finding)
            ReadingFindBar(
              query: _query,
              focus: _findFocus,
              found: _hits.length,
              chosen: _hit,
              onChanged: (_) => _search(),
              onStep: _step,
              onClose: _closeFind,
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight / 3),
            child: ClipRect(
              child: Text(
                context.mtl.desktopTranscriptHint,
                style: text.labelSmall?.copyWith(color: p.ink3),
              ),
            ),
          ),
          const SizedBox(height: MTSpace.sm),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                if (n.direction != ScrollDirection.idle) {
                  _scrolledByHand = DateTime.now();
                }
                return false;
              },
              // A column, not a lazy list, so the line being said always has
              // a place to scroll to; a transcript is a few hundred lines.
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, line) in widget.segments.indexed)
                      TranscriptLine(
                        key: chosen?.line == i
                            ? _found
                            : (i == _now ? _current : null),
                        line: line,
                        current: i == _now,
                        marks: [
                          for (final h in _hits)
                            if (h.line == i) (h.start, h.end),
                        ],
                        chosen: chosen?.line == i
                            ? (chosen!.start, chosen.end)
                            : null,
                        onTap: () => unawaited(widget.player.seek(line.start)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
