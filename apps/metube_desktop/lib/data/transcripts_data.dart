import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import 'library_data.dart';

/// The transcripts on this computer, in `%APPDATA%\MeTube Ember\transcripts\`
/// and in the phone's format, so an exported bundle reads the same here.
/// Overridden in main; null (tests) means none.
final transcriptStoreProvider = Provider<TranscriptStore?>((ref) => null);

/// Which clip's transcript to show: its key, and its file on the server,
/// beside which the server keeps the subtitles it downloaded.
typedef TranscriptKey = ({String canonicalUrl, String? serverFilename});

/// The transcript of one clip, in the reader's language when there is a
/// choice.
///
/// **Read from this computer first; failing that, once from the server**:
/// a clip whose subtitles the server saved beside it (a `.vtt` next to the
/// file, as the phone's backfill reads them) is fetched the first time it
/// plays, then kept. Kept for the session too, so a clip with none is not
/// asked about again on every play.
final transcriptForProvider = FutureProvider.family<Transcript?, TranscriptKey>(
  (ref, key) async {
    final store = ref.watch(transcriptStoreProvider);
    if (store == null) return null;
    final languages = _readerLanguages();
    final stored = await store.readFor(key.canonicalUrl);
    if (stored.isNotEmpty) return _pick(stored, languages);

    final api = ref.watch(apiClientProvider);
    final filename = key.serverFilename;
    if (api == null || filename == null) return null;
    final reader = SidecarReader(api);
    for (final language in languages) {
      final result = await reader.read(
        canonicalUrl: key.canonicalUrl,
        filename: filename,
        language: language,
      );
      if (result.outcome == SidecarOutcome.failed) return null;
      if (result.transcript case final found?) {
        await store.write(found);
        return found;
      }
    }
    return null;
  },
);

/// The reader's language first, then English, which most clips have.
List<String> _readerLanguages() {
  final own = PlatformDispatcher.instance.locale.languageCode;
  return {own, 'en'}.toList();
}

/// The transcript in the first of [languages] there is one for, else the
/// first one kept.
Transcript _pick(List<Transcript> all, List<String> languages) {
  for (final language in languages) {
    for (final t in all) {
      if (Transcript.baseLanguage(t.language) == language) return t;
    }
  }
  return all.first;
}
