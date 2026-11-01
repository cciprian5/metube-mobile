import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import 'subtitles.dart';
import 'transcript_language.dart';
import 'transcripts_state.dart';

/// A clip's chapters, worked out from its transcript in [language] (else
/// the app's own) and kept for the session: the player asks on every
/// frame, and cutting a long talk into chapters is not free.
final clipChaptersProvider =
    Provider.family<List<MTChapter>, ({String url, String? language})>((
      ref,
      key,
    ) {
      if (!(ref.watch(transcriptsEnabledProvider).valueOrNull ?? false)) {
        return const [];
      }
      ref.watch(transcriptsRevisionProvider);
      final kept =
          ref
              .watch(transcriptIndexProvider)
              .valueOrNull
              ?.transcriptsFor(key.url) ??
          const <Transcript>[];
      final shown = preferredTranscript(
        kept,
        chosen: key.language,
        interface: ref.read(transcriptsServiceProvider).languages.first,
      );
      return shown == null ? const [] : chaptersOf(shown.segments);
    });

/// The chapters of [item], in the language its subtitles are shown in.
/// Empty without a transcript, for a clip under four minutes, and for one
/// whose words give fewer than three.
List<MTChapter> chaptersFor(WidgetRef ref, PlaylistItem item) => ref.read(
  clipChaptersProvider((
    url: item.canonicalUrl,
    language: ref.read(subtitlePrefsProvider).language.value,
  )),
);
