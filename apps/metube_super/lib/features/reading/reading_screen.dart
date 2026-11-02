import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'reading_export.dart';
import 'reading_paragraph.dart';
import 'reading_parts.dart';
import 'reading_pdf.dart';

/// Opens [transcript] as an article, above the whole app. [onMoment] plays
/// from a moment when the clip is not the one playing.
Future<void> openReading(
  BuildContext context, {
  required String title,
  required Transcript transcript,
  required void Function(Duration start) onMoment,
  String? byline,
  ReadingPlayback? playback,
}) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) => ReadingScreen(
      title: title,
      byline: byline,
      transcript: transcript,
      playback: playback,
      onMoment: onMoment,
    ),
  ),
);

/// **Reading mode** (mobile plan, stage 16/F, after the Windows app's
/// reading room): the transcript as prose, its chapters as headings with
/// their times, the sentence being said on a grey ground while the clip
/// plays, the clip's bar beneath, a search, the text's size, and the text
/// shared as plain text, Markdown, subtitles or a PDF.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.title,
    required this.transcript,
    required this.onMoment,
    this.byline,
    this.playback,
  });

  final String title;
  final String? byline;
  final Transcript transcript;
  final void Function(Duration start) onMoment;
  final ReadingPlayback? playback;

  /// The text's sizes the size button steps through.
  static const sizes = [0.9, 1.0, 1.2];

  /// Words read in a minute, for how long the text takes.
  static const wordsPerMinute = 200;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late final _segments = widget.transcript.segments;
  late final _paragraphs = paragraphsOf(_segments);
  late final _keys = [for (final _ in _paragraphs) GlobalKey()];

  /// Paragraph index to chapter number, for those a chapter begins with.
  late final Map<int, int> _chapters = {
    for (final (n, chapter) in chaptersOf(_segments).indexed)
      ?_paragraphAt(chapter.start): n + 1,
  };
  final _field = TextEditingController();
  StreamSubscription<Duration>? _positions;
  int? _now;
  bool _finding = false;
  List<FindHit> _hits = const [];
  int? _hit;
  int _size = 1;
  DateTime _scrolledByHand = DateTime.fromMillisecondsSinceEpoch(0);

  /// Following waits this long after a scroll by hand.
  static const _handPause = Duration(seconds: 6);

  int? _paragraphAt(Duration start) {
    final at = _paragraphs.indexWhere((p) => _segments[p.first].start == start);
    return at < 0 ? null : at;
  }

  @override
  void initState() {
    super.initState();
    _positions = widget.playback?.positions().listen(_follow);
  }

  @override
  void dispose() {
    unawaited(_positions?.cancel());
    _field.dispose();
    super.dispose();
  }

  void _follow(Duration position) {
    final playback = widget.playback;
    final now = playback != null && playback.stillPlaying()
        ? segmentAt(_segments, position)
        : null;
    if (now == _now || !mounted) return;
    setState(() => _now = now);
    final handPause = DateTime.now().difference(_scrolledByHand) < _handPause;
    if (now != null && _hit == null && !handPause) _reveal(now, 0.3);
  }

  /// Scrolls the paragraph holding line [index] into view.
  void _reveal(int index, double alignment) {
    final at = _paragraphs.indexWhere((p) => p.last >= index);
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

  void _jump(int line) {
    final start = _segments[line].start;
    final playback = widget.playback;
    if (playback != null && playback.stillPlaying()) {
      unawaited(playback.seek(start));
    } else {
      widget.onMoment(start);
    }
  }

  void _find() {
    setState(() {
      _hits = findIn(_segments, _field.text);
      _hit = _hits.isEmpty ? null : 0;
    });
    if (_hits.isNotEmpty) _reveal(_hits.first.line, 0.4);
  }

  void _step(int by) {
    if (_hits.isEmpty) return;
    final next = ((_hit ?? 0) + by) % _hits.length;
    setState(() => _hit = next);
    _reveal(_hits[next].line, 0.4);
  }

  void _closeFind() => setState(() {
    _finding = false;
    _field.clear();
    _hits = const [];
    _hit = null;
  });

  int get _minutes {
    final words = _segments.fold(
      0,
      (sum, s) => sum + s.text.trim().split(RegExp(r'\s+')).length,
    );
    return (words / ReadingScreen.wordsPerMinute).ceil().clamp(1, 1 << 30);
  }

  String get _meta => mtMetaLine([
    widget.byline,
    if (_segments.isNotEmpty) mtLtrRun(mtFormatDuration(_segments.last.end)),
    context.mtl.readingMinutes(_minutes),
    if (_chapters.isNotEmpty) context.mtl.chapterCount(_chapters.length),
  ]);

  Future<void> _share() async {
    final form = await pickReadingExport(context);
    if (form == null || !mounted) return;
    final url = widget.transcript.canonicalUrl;
    if (form == ReadingExport.text) {
      await Share.share(
        plainTextOf(title: widget.title, paragraphs: _paragraphs),
      );
      return;
    }
    final direction = Directionality.of(context);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${exportName(widget.title, form)}');
    switch (form) {
      case ReadingExport.markdown:
        await file.writeAsString(
          markdownOf(
            title: widget.title,
            meta: _meta,
            canonicalUrl: url,
            paragraphs: _paragraphs,
            segments: _segments,
          ),
        );
      case ReadingExport.srt:
        await file.writeAsString(srtOf(_segments));
      case ReadingExport.pdf:
        await file.writeAsBytes(
          await pdfOf(
            fonts: await loadReadingFonts(),
            title: widget.title,
            meta: _meta,
            canonicalUrl: url,
            paragraphs: _paragraphs,
            segments: _segments,
            fallback: direction,
          ),
        );
      case ReadingExport.text:
        return;
    }
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final playback = widget.playback;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => setState(() => _finding = true),
            tooltip: l.desktopReadingFind,
            icon: const MTIcon(MTIcons.search),
          ),
          IconButton(
            onPressed: () => setState(
              () => _size = (_size + 1) % ReadingScreen.sizes.length,
            ),
            tooltip: l.readingTextSize,
            icon: const MTIcon(MTIcons.textSize),
          ),
          IconButton(
            onPressed: _share,
            tooltip: l.readingShare,
            icon: const MTIcon(MTIcons.share),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_finding)
            ReadingFindBar(
              field: _field,
              at: _hit,
              count: _hits.length,
              onChanged: _find,
              onStep: _step,
              onClose: _closeFind,
            ),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                if (n.direction != ScrollDirection.idle) {
                  _scrolledByHand = DateTime.now();
                }
                return false;
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MTSpace.pagePad,
                  MTSpace.xs,
                  MTSpace.pagePad,
                  MTSpace.xl,
                ),
                child: MTReadableWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MTForeignText(
                        widget.title,
                        style: text.titleLarge!.copyWith(color: p.ink),
                      ),
                      const SizedBox(height: MTSpace.xxs),
                      Text(
                        _meta,
                        style: text.bodySmall!.copyWith(color: p.ink3),
                      ),
                      const SizedBox(height: MTSpace.xs),
                      Text(
                        l.readingHint,
                        style: text.labelSmall!.copyWith(color: p.ink3),
                      ),
                      Divider(height: MTSpace.xl, color: p.line),
                      for (final (i, paragraph) in _paragraphs.indexed)
                        ReadingParagraphView(
                          key: _keys[i],
                          paragraph: paragraph,
                          segments: _segments,
                          chapter: _chapters[i],
                          now: _now,
                          hits: _hits,
                          hit: _hit,
                          scale: ReadingScreen.sizes[_size],
                          onJump: _jump,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (playback != null && playback.stillPlaying())
            ReadingPlaybackBar(title: widget.title, playback: playback),
        ],
      ),
    );
  }
}
