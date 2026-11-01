import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

/// The quote as it is copied: the words, where they come from and when,
/// and a link to the moment they begin.
String quoteText(
  MTLocalizations l, {
  required Quote quote,
  required List<TranscriptSegment> segments,
  required String title,
  required String canonicalUrl,
}) {
  final from = segments[quote.first].start;
  final to = segments[quote.last].end;
  return l.desktopQuote(
    quote.text,
    title,
    '${mtFormatDuration(from)}–${mtFormatDuration(to)}',
    timedLink(canonicalUrl, from),
  );
}
