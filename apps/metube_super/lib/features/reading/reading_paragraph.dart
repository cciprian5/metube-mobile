import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

/// One paragraph of the reading page: a chapter's heading above it when
/// one begins here, then its prose, the sentence being said on a grey
/// ground and what the search found lit. A tap on a sentence plays from it.
class ReadingParagraphView extends StatelessWidget {
  const ReadingParagraphView({
    super.key,
    required this.paragraph,
    required this.segments,
    required this.now,
    required this.hits,
    required this.hit,
    required this.scale,
    required this.onJump,
    this.chapter,
  });

  final ReadingParagraph paragraph;
  final List<TranscriptSegment> segments;
  final int? now;
  final List<FindHit> hits;
  final int? hit;

  /// The reader's chosen size, over the body text's own.
  final double scale;
  final ValueChanged<int> onJump;

  /// The number of the chapter that begins with this paragraph, if any.
  final int? chapter;

  /// The line under a tap, found from where in the text it fell.
  void _tapped(BuildContext context, TapUpDetails details) {
    RenderParagraph? text;
    void find(RenderObject node) {
      if (text != null) return;
      if (node is RenderParagraph) {
        text = node;
      } else {
        node.visitChildren(find);
      }
    }

    if (context.findRenderObject() case final box?) find(box);
    final found = text;
    if (found == null) return;
    final at = found
        .getPositionForOffset(found.globalToLocal(details.globalPosition))
        .offset;
    var line = paragraph.first;
    for (var i = paragraph.first; i <= paragraph.last; i++) {
      if (paragraph.offsetOf(i) <= at) line = i;
    }
    onJump(line);
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final base = text.bodyLarge!.copyWith(
      color: p.ink2,
      height: 1.9,
      fontSize: text.bodyLarge!.fontSize! * scale,
    );
    final spans = <InlineSpan>[];
    for (var i = paragraph.first; i <= paragraph.last; i++) {
      final words = paragraph.lines[i - paragraph.first];
      final style = i == now
          ? base.copyWith(color: p.ink, backgroundColor: mtSelectedFill(p))
          : base;
      var at = 0;
      for (final (n, h) in hits.indexed) {
        if (h.line != i) continue;
        if (h.start > at) {
          spans.add(TextSpan(text: words.substring(at, h.start), style: style));
        }
        final chosen = n == hit;
        spans.add(
          TextSpan(
            text: words.substring(h.start, h.end),
            style: style.copyWith(
              fontWeight: FontWeight.w700,
              color: chosen ? p.onAccent : p.accentInk,
              backgroundColor: chosen ? p.accent : p.accentSoft,
            ),
          ),
        );
        at = h.end;
      }
      final rest = words.substring(at) + (i < paragraph.last ? ' ' : '');
      spans.add(TextSpan(text: rest, style: style));
    }
    final start = segments[paragraph.first].start;
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chapter case final number?)
            Padding(
              padding: const EdgeInsets.only(
                top: MTSpace.md,
                bottom: MTSpace.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.mtl.chapterNumber(number),
                      style: text.labelMedium!.copyWith(color: p.ink3),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onJump(paragraph.first),
                    child: Text(
                      mtLtrRun(mtFormatDuration(start)),
                      style: text.labelSmall!
                          .copyWith(color: p.accentInk)
                          .tabular,
                    ),
                  ),
                ],
              ),
            ),
          Builder(
            builder: (prose) => GestureDetector(
              onTapUp: (details) => _tapped(prose, details),
              child: Text.rich(
                TextSpan(children: spans),
                textDirection: mtTextDirectionOf(
                  paragraph.text,
                  Directionality.of(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
