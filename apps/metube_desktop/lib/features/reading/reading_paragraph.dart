import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'reading_text.dart';

/// One paragraph: its time in the margin, then its prose.
class ReadingParagraphView extends StatelessWidget {
  const ReadingParagraphView({
    super.key,
    required this.paragraph,
    required this.segments,
    required this.now,
    required this.hits,
    required this.hit,
    required this.onJump,
  });

  final ReadingParagraph paragraph;
  final List<TranscriptSegment> segments;
  final int? now;
  final List<FindHit> hits;
  final int? hit;
  final ValueChanged<int> onJump;

  /// The line under a click, found from where in the text it fell.
  void _tapped(BuildContext context, TapUpDetails details) {
    final box = context.findRenderObject();
    RenderParagraph? text;
    void find(RenderObject node) {
      if (text != null) return;
      if (node is RenderParagraph) {
        text = node;
      } else {
        node.visitChildren(find);
      }
    }

    if (box != null) find(box);
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
    final base = text.bodyLarge?.copyWith(color: p.ink2, height: 1.9);
    final spans = <InlineSpan>[];
    for (var i = paragraph.first; i <= paragraph.last; i++) {
      final words = paragraph.lines[i - paragraph.first];
      final lit = i == now;
      final style = lit
          ? base?.copyWith(color: p.ink, backgroundColor: p.accentSoft)
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
            style: style?.copyWith(
              fontWeight: FontWeight.w700,
              color: chosen ? p.onAccent : p.accentInk,
              backgroundColor: chosen ? p.accent : null,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The time, a way to the paragraph for the keyboard too, and no
          // part of what is selected and copied.
          SelectionContainer.disabled(
            child: SizedBox(
              width: MTSpace.xxl * 2,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: TextButton(
                  onPressed: () => onJump(paragraph.first),
                  child: Text(
                    mtLtrRun(mtFormatDuration(start)),
                    style: text.labelSmall?.tabular.copyWith(
                      color: p.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Builder(
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
            ),
          ),
        ],
      ),
    );
  }
}
