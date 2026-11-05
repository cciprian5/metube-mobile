import 'package:mt_transcripts/mt_transcripts.dart';

/// The transcript to show first: the language the user last picked, in the
/// music player or with the video's subtitle switch, then the app's own
/// language, then English. **One choice for every player** (owner's
/// decision, 2026-11-01): picking English under the music player also
/// turns the video's subtitles to English.
///
/// Null when none of those has words: a transcript in another language is
/// never put in front of the reader unasked (owner's decision 2026-11-04),
/// though a switch or the full transcript still offers it.
Transcript? preferredTranscript(
  List<Transcript> transcripts, {
  required String? chosen,
  required String interface,
}) {
  final spoken = [
    for (final t in transcripts)
      if (!t.isEmpty) t,
  ];
  for (final code in [chosen, interface, 'en']) {
    for (final t in spoken) {
      if (t.language == code) return t;
    }
  }
  return null;
}

/// The language after [current] among the transcripts with words, back to
/// the first after the last, so one tap switches between two.
String nextLanguage(List<Transcript> transcripts, String current) {
  final codes = [
    for (final t in transcripts)
      if (!t.isEmpty) t.language,
  ];
  final at = codes.indexOf(current);
  return codes[(at + 1) % codes.length];
}
