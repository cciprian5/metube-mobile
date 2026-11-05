import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_actions.dart';
import '../library/library_providers.dart';
import '../library/widgets/item_details_sheet.dart';
import '../player/playback_providers.dart';
import '../transcripts/subtitles.dart';
import '../transcripts/transcript_language.dart';
import '../transcripts/transcript_openers.dart';
import '../transcripts/transcript_peek.dart';
import '../transcripts/transcripts_state.dart';

/// The full audio screen in Super (`/audio`): the content comes from
/// mt_media, and the clip details from the app layer, since mt_media does
/// not know the library indexes.
class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    // Empty while transcripts are off, so the button never shows then.
    final transcripts = ref.watch(transcriptIndexProvider).valueOrNull;
    ref.watch(transcriptsRevisionProvider);
    final library = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    return MTAudioScreen(
      handler: handler,
      artwork: artworkBuilderFor(ref),
      cover: coverBuilderFor(ref),
      // **A details button instead of a queue button** (field report
      // 2026-09-05): the queue already has its visible button at the bottom
      // of
      // the screen.
      onDetails: () => _showDetails(context, ref, handler),
      extra: (item) => (transcripts?.contains(item.canonicalUrl) ?? false)
          ? MTExtraAction(
              icon: MTIcons.transcript,
              label: context.mtl.transcript,
              onTap: () => showPlayingTranscript(context, handler, item),
            )
          : null,
      companion: audioTranscriptPanels(context, handler),
      // The line being said, under the controls on a tall phone; the
      // transcript button above stands in for it everywhere else.
      peek: (item) {
        final all = transcripts?.transcriptsFor(item.canonicalUrl) ?? [];
        final chosen = ref.read(subtitlePrefsProvider).language;
        // Only another language kept: the transcript button offers it,
        // the peek does not show it unasked.
        final shown = preferredTranscript(
          all,
          chosen: chosen.value,
          interface: Localizations.localeOf(context).languageCode,
        );
        if (shown == null) return null;
        return PlayingTranscriptPeek(
          transcripts: all,
          chosen: chosen,
          position: handler.positionStream,
          onOpen: () => showPlayingTranscript(context, handler, item),
        );
      },
      // The one-tap heart lives here and in the video player; the library
      // cards show it on favourites alone.
      isFavorite: (item) => library.any(
        (candidate) =>
            candidate.canonicalUrl == item.canonicalUrl && candidate.favorite,
      ),
      onFavorite: (item) =>
          ref.read(libraryActionsProvider).toggleFavorite(item.canonicalUrl),
    );
  }

  void _showDetails(
    BuildContext context,
    WidgetRef ref,
    MTAudioHandler handler,
  ) {
    final key = handler.currentItem?.canonicalUrl;
    if (key == null) return;
    final items = ref.read(libraryItemsProvider).valueOrNull ?? const [];
    for (final candidate in items) {
      if (candidate.canonicalUrl == key) {
        showItemDetailsSheet(context, candidate);
        return;
      }
    }
  }
}
