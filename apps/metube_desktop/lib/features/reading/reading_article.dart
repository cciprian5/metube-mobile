import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'reading_paragraph.dart';

/// **The transcript as an article**: paragraphs at a readable width, the
/// line being said lit and kept in view while this clip plays, a click on
/// a sentence playing from it, and what the find bar found lit too. A
/// selection is copied by [onCopy] (Ctrl+C or the right-click menu) with
/// its time and link; [selection] tells which part of the text it is.
class ReadingArticle extends StatefulWidget {
  const ReadingArticle({
    super.key,
    required this.header,
    required this.segments,
    required this.paragraphs,
    required this.player,
    required this.following,
    required this.hits,
    required this.hit,
    required this.selection,
    required this.onJump,
    required this.onCopy,
  });

  final Widget header;
  final List<TranscriptSegment> segments;
  final List<ReadingParagraph> paragraphs;
  final MTPlayer player;

  /// Whether this clip is the one playing, so its line being said is lit.
  final bool following;
  final List<FindHit> hits;

  /// The found place chosen in [hits], or null when not finding.
  final int? hit;
  final SelectionListenerNotifier selection;

  /// Plays from line [index] of the transcript.
  final ValueChanged<int> onJump;
  final VoidCallback onCopy;

  @override
  State<ReadingArticle> createState() => _ReadingArticleState();
}

class _ReadingArticleState extends State<ReadingArticle> {
  late List<GlobalKey> _keys = _keysFor(widget.paragraphs);
  StreamSubscription<Duration>? _positions;
  int? _now;

  /// Following waits a moment after a scroll by hand, so reading ahead or
  /// back is not pulled to the line being said.
  DateTime _scrolledByHand = DateTime.fromMillisecondsSinceEpoch(0);
  static const _handPause = Duration(seconds: 6);

  static List<GlobalKey> _keysFor(List<ReadingParagraph> paragraphs) => [
    for (final _ in paragraphs) GlobalKey(),
  ];

  @override
  void initState() {
    super.initState();
    _show(widget.player.position);
    _positions = widget.player.positionStream.listen(_show);
  }

  @override
  void didUpdateWidget(ReadingArticle old) {
    super.didUpdateWidget(old);
    if (old.paragraphs != widget.paragraphs) {
      _keys = _keysFor(widget.paragraphs);
    }
    if (old.following != widget.following) _show(widget.player.position);
    final hit = widget.hit;
    if (hit != null && (hit != old.hit || old.hits != widget.hits)) {
      _reveal(widget.hits[hit].line, alignment: 0.4);
    }
  }

  @override
  void dispose() {
    unawaited(_positions?.cancel());
    super.dispose();
  }

  void _show(Duration position) {
    final now = widget.following ? segmentAt(widget.segments, position) : null;
    if (now == _now || !mounted) return;
    setState(() => _now = now);
    final handPause = DateTime.now().difference(_scrolledByHand) < _handPause;
    if (now != null && widget.hit == null && !handPause) {
      _reveal(now, alignment: 0.3);
    }
  }

  /// Scrolls the paragraph holding line [index] into view.
  void _reveal(int index, {required double alignment}) {
    final at = widget.paragraphs.indexWhere((p) => p.last >= index);
    if (at < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[at].currentContext;
      if (target == null || !target.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: alignment,
          duration: mtMotionDuration(context, MTMotion.medium),
          curve: MTMotion.ease,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final hit = widget.hit;
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        if (n.direction != ScrollDirection.idle) {
          _scrolledByHand = DateTime.now();
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MTSpace.xl),
        child: MTReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.header,
              // Ctrl+C here, before the app's own copy, which would take
              // the bare words.
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyC, control: true):
                      widget.onCopy,
                },
                child: SelectionArea(
                  contextMenuBuilder: (context, state) =>
                      AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: state.contextMenuAnchors,
                        buttonItems: [
                          ContextMenuButtonItem(
                            label: l.desktopCopyQuote,
                            onPressed: () {
                              widget.onCopy();
                              state.hideToolbar();
                            },
                          ),
                        ],
                      ),
                  child: SelectionListener(
                    selectionNotifier: widget.selection,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, paragraph) in widget.paragraphs.indexed)
                          ReadingParagraphView(
                            key: _keys[i],
                            paragraph: paragraph,
                            segments: widget.segments,
                            now: _now,
                            hits: widget.hits,
                            hit: hit,
                            onJump: widget.onJump,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
