import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:share_plus/share_plus.dart';

/// The lines a quote holds, the first and the last.
typedef QuoteRange = ({int first, int last});

/// [range] grown to take in line [index].
QuoteRange extendQuote(QuoteRange range, int index) => (
  first: index < range.first ? index : range.first,
  last: index > range.last ? index : range.last,
);

/// The quote as it is copied and shared: the words, where they come from
/// and when, and a link to the moment they begin (to its second on
/// YouTube), in the same form as the Windows app's.
String quoteText(
  MTLocalizations l, {
  required List<TranscriptSegment> segments,
  required QuoteRange range,
  required String title,
  required String canonicalUrl,
}) {
  final from = segments[range.first].start;
  final to = segments[range.last].end;
  return l.desktopQuote(
    [for (var i = range.first; i <= range.last; i++) segments[i].text.trim()]
        .join(' '),
    title,
    '${mtFormatDuration(from)}–${mtFormatDuration(to)}',
    timedLink(canonicalUrl, from),
  );
}

/// **The quote under a transcript**, opened by a long press on a line:
/// what will be copied, and what can be done with it. Touching another
/// line meanwhile takes it in.
class TranscriptQuotePanel extends StatefulWidget {
  const TranscriptQuotePanel({
    super.key,
    required this.text,
    required this.link,
    required this.onPlay,
    required this.onClose,
  });

  /// The quote as [quoteText] words it.
  final String text;

  /// The moment it begins.
  final String link;
  final VoidCallback onPlay;
  final VoidCallback onClose;

  @override
  State<TranscriptQuotePanel> createState() => _TranscriptQuotePanelState();
}

class _TranscriptQuotePanelState extends State<TranscriptQuotePanel> {
  /// What was just copied, said in place: a notice at the foot of the
  /// screen would sit under the sheet this panel lives in.
  String? _copied;

  @override
  void didUpdateWidget(TranscriptQuotePanel old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _copied = null;
  }

  Future<void> _copy(String what, String said) async {
    await Clipboard.setData(ClipboardData(text: what));
    if (mounted) setState(() => _copied = said);
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(MTRadius.card);
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: p.line, width: MTThemeX.of(context).hairline),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.md,
          MTSpace.xs,
          MTSpace.xs,
          MTSpace.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.quoteTitle, style: text.titleSmall)),
                IconButton(
                  onPressed: widget.onClose,
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: MTSpace.sm),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.bg,
                  borderRadius: BorderRadius.circular(MTRadius.field),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(MTSpace.sm),
                  child: MTForeignText(
                    widget.text,
                    maxLines: 5,
                    style: text.bodySmall!.copyWith(color: p.ink),
                  ),
                ),
              ),
            ),
            const SizedBox(height: MTSpace.xs),
            Row(
              children: [
                if (_copied != null) ...[
                  Icon(Icons.check_rounded, size: 16, color: p.ok),
                  const SizedBox(width: MTSpace.xxs),
                ],
                Expanded(
                  child: Text(
                    _copied ?? l10n.quoteExtendHint,
                    style: text.labelSmall!.copyWith(
                      color: _copied == null ? p.ink3 : p.ink,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              children: [
                TextButton.icon(
                  onPressed: () => _copy(widget.text, l10n.desktopQuoteCopied),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(l10n.desktopCopyQuote),
                ),
                TextButton.icon(
                  onPressed: () => Share.share(widget.text),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: Text(l10n.share),
                ),
                TextButton.icon(
                  onPressed: () => _copy(widget.link, l10n.desktopLinkCopied),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(l10n.quoteMomentLink),
                ),
                TextButton.icon(
                  onPressed: widget.onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(l10n.quotePlayFrom),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
