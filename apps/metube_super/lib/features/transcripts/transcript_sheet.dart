import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'transcript_heading.dart';
import 'transcript_language.dart';
import 'transcript_lines.dart';
import 'transcript_quote.dart';

/// A clip's whole transcript: in a bottom sheet, or in a panel beside a
/// full-screen video when [onClose] is given.
class TranscriptSheet extends StatefulWidget {
  const TranscriptSheet({
    super.key,
    required this.title,
    required this.query,
    required this.transcripts,
    required this.onMoment,
    this.position,
    this.stillPlaying,
    this.onClose,
    this.language,
    this.onRead,
  });

  final String title;
  final String query;
  final List<Transcript> transcripts;
  final void Function(Duration start) onMoment;

  /// Where playback is, for a transcript that follows it.
  final Stream<Duration>? position;

  /// False once another item plays: the transcript then closes.
  final bool Function()? stillPlaying;

  /// Closes the panel this transcript sits in; null in a sheet.
  final VoidCallback? onClose;

  /// The language picked last, shared with the players: it opens the text
  /// and follows a pick made here.
  final ValueNotifier<String?>? language;

  /// Opens the transcript shown as an article.
  final ValueChanged<Transcript>? onRead;

  @override
  State<TranscriptSheet> createState() => _TranscriptSheetState();
}

class _TranscriptSheetState extends State<TranscriptSheet> {
  late final _field = TextEditingController(text: widget.query);
  final _lines = GlobalKey<TranscriptLinesState>();
  final _panelScroll = ScrollController();
  Transcript? _shown;
  int? _now;

  /// The quote being made, from a long press on a line.
  QuoteRange? _quote;
  bool _searching = false;
  int _cursor = 0;
  StreamSubscription<Duration>? _ticks;

  String get _query => _field.text;

  @override
  void initState() {
    super.initState();
    _ticks = widget.position?.listen(_onPosition);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown ??= _opening(Localizations.localeOf(context).languageCode);
  }

  @override
  void dispose() {
    _ticks?.cancel();
    _field.dispose();
    _panelScroll.dispose();
    super.dispose();
  }

  /// The language holding the words searched for; with nothing searched,
  /// the interface's own.
  Transcript _opening(String interface) {
    if (_query.trim().isEmpty) {
      return preferredTranscript(
            widget.transcripts,
            chosen: widget.language?.value,
            interface: interface,
          ) ??
          widget.transcripts.first;
    }
    var best = widget.transcripts.first;
    var bestCount = -1;
    for (final transcript in widget.transcripts) {
      final count = _matches(transcript).length;
      if (count > bestCount) (best, bestCount) = (transcript, count);
    }
    return best;
  }

  List<int> _matches(Transcript transcript) => [
    if (_query.trim().isNotEmpty)
      for (var i = 0; i < transcript.segments.length; i++)
        if (SearchText.matchRanges(
          transcript.segments[i].text,
          _query,
        ).isNotEmpty)
          i,
  ];

  void _onPosition(Duration position) {
    if (!(widget.stillPlaying?.call() ?? true)) {
      _ticks?.cancel();
      if (widget.onClose case final close?) {
        close();
      } else {
        Navigator.maybePop(context);
      }
      return;
    }
    final now = TranscriptLines.lineAt(_shown!.segments, position);
    if (now == _now) return;
    setState(() => _now = now);
    // A search is the reader looking for something: playback marks its
    // line but does not pull the view away from the match being read.
    if (now != null && _query.trim().isEmpty) {
      _lines.currentState?.follow(now);
    }
  }

  void _show(Transcript transcript) {
    widget.language?.value = transcript.language;
    setState(() {
      _shown = transcript;
      _quote = null;
    });
    _restartMatches();
  }

  void _restartMatches() {
    _cursor = 0;
    final first = _matches(_shown!).firstOrNull ?? _now;
    if (first != null) _lines.currentState?.reveal(first);
  }

  void _step(int step) {
    final matches = _matches(_shown!);
    if (matches.isEmpty) return;
    _cursor = (_cursor + step) % matches.length;
    _lines.currentState?.reveal(matches[_cursor]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onClose == null) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scroll) => Padding(
          padding: EdgeInsets.fromLTRB(
            MTSpace.xl,
            MTSpace.lg,
            MTSpace.xl,
            mtSheetBottomPad(context),
          ),
          child: _body(scroll),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.lg,
        MTSpace.md,
        MTSpace.lg,
        MTSpace.md,
      ),
      child: _body(_panelScroll),
    );
  }

  Widget _body(ScrollController scroll) {
    final shown = _shown!;
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At the largest text size on a short phone the heading alone
          // outgrew the sheet; it now yields, scrolling on its own, and the
          // lines always keep half.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight / 2),
            child: SingleChildScrollView(
              child: TranscriptHeading(
                title: widget.title,
                transcripts: widget.transcripts,
                shown: shown,
                query: _query,
                matchCount: _matches(shown).length,
                searching: _searching,
                field: _field,
                onSearchToggle: () => setState(() => _searching = !_searching),
                onQueryChanged: () {
                  setState(() {});
                  _restartMatches();
                },
                onStep: _step,
                onShow: _show,
                onClose: widget.onClose,
                onRead: switch (widget.onRead) {
                  final read? => () => read(shown),
                  null => null,
                },
              ),
            ),
          ),
          const SizedBox(height: MTSpace.sm),
          Expanded(
            child: TranscriptLines(
              key: _lines,
              segments: shown.segments,
              query: _query,
              following: widget.position != null,
              now: _now,
              controller: scroll,
              opening: _matches(shown).firstOrNull,
              onMoment: widget.onMoment,
              quote: _quote,
              onQuote: (index, {required longPress}) => setState(
                () => _quote = longPress || _quote == null
                    ? (first: index, last: index)
                    : extendQuote(_quote!, index),
              ),
            ),
          ),
          if (_quote case final quote?) ...[
            const SizedBox(height: MTSpace.sm),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.55),
              child: TranscriptQuotePanel(
                text: quoteText(
                  context.mtl,
                  segments: shown.segments,
                  range: quote,
                  title: widget.title,
                  canonicalUrl: shown.canonicalUrl,
                ),
                link: timedLink(
                  shown.canonicalUrl,
                  shown.segments[quote.first].start,
                ),
                onPlay: () {
                  setState(() => _quote = null);
                  widget.onMoment(shown.segments[quote.first].start);
                },
                onClose: () => setState(() => _quote = null),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
