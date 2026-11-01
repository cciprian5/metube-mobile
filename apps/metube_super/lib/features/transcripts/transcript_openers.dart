import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_media/library.dart';

import '../reading/reading_parts.dart';
import '../reading/reading_screen.dart';
import 'clip_chapters.dart';
import 'subtitles.dart';
import 'transcript_moment.dart';
import 'transcript_panel_tabs.dart';
import 'transcript_sheet.dart';
import 'transcripts_state.dart';

/// Opens a clip's whole transcript, with [query] lit wherever it was said.
///
/// Every line plays the clip from its second. [context] belongs to the
/// screen underneath, which outlives the sheet: a tap closes the sheet
/// first, then plays from there.
void showTranscriptSheet(BuildContext context, LibraryItem item, String query) {
  final container = ProviderScope.containerOf(context, listen: false);
  final transcripts = _transcriptsOf(container, item.canonicalUrl);
  if (transcripts.isEmpty) return;
  _open(
    context,
    (sheetContext) => TranscriptSheet(
      title: item.title,
      query: query,
      transcripts: transcripts,
      language: container.read(subtitlePrefsProvider).language,
      onMoment: (start) {
        Navigator.pop(sheetContext);
        playFromMoment(context, container.read, item, start);
      },
      onRead: (transcript) => openReading(
        context,
        title: item.title,
        byline: item.uploader,
        transcript: transcript,
        onMoment: (start) =>
            playFromMoment(context, container.read, item, start),
      ),
    ),
  );
}

/// Opens the transcript of the item [handler] is playing, following along:
/// the line being said is marked and kept in view, and a tap on any line
/// jumps there without leaving the player. It closes itself when the queue
/// moves on, rather than follow another item's time with the wrong words.
void showPlayingTranscript(
  BuildContext context,
  MTAudioHandler handler,
  PlaylistItem playing,
) => _openFollowing(
  context,
  playing,
  positions: () => handler.positionStream,
  stillPlaying: () => handler.currentItem?.canonicalUrl == playing.canonicalUrl,
  seek: handler.seek,
  isPlaying: handler.playbackState.map((state) => state.playing),
  playPause: () => _audioPlayPause(handler),
);

/// The same, for the video [session] is playing.
void showVideoTranscript(
  BuildContext context,
  MTVideoSession session,
  PlaylistItem playing,
) => _openFollowing(
  context,
  playing,
  positions: () => videoPositions(session),
  stillPlaying: () => session.current?.canonicalUrl == playing.canonicalUrl,
  seek: session.seek,
  isPlaying: videoPlaying(session),
  playPause: session.playPause,
);

/// The same, for the reel on screen, so the shorts reach the transcript
/// the other players offer.
void showReelTranscript(
  BuildContext context,
  MTReelsHandle reel,
  PlaylistItem playing,
) => _openFollowing(
  context,
  playing,
  positions: () =>
      Stream.periodic(const Duration(milliseconds: 250), (_) => reel.position),
  stillPlaying: () => reel.current?.canonicalUrl == playing.canonicalUrl,
  seek: reel.seek,
);

/// The transcript as a panel beside a full-screen video, for the items
/// that have one.
MTVideoPanel? Function(PlaylistItem item) transcriptPanels(
  BuildContext context,
  MTVideoSession session,
) {
  final container = ProviderScope.containerOf(context, listen: false);
  final label = context.mtl.transcript;
  return (item) {
    final transcripts = _transcriptsOf(container, item.canonicalUrl);
    if (transcripts.isEmpty) return null;
    final language = container.read(subtitlePrefsProvider).language;
    final chapters = container.read(
      clipChaptersProvider((url: item.canonicalUrl, language: language.value)),
    );
    return MTVideoPanel(
      icon: Icons.subject_rounded,
      label: label,
      builder: (context, close) {
        final transcript = TranscriptSheet(
          title: item.title,
          query: '',
          transcripts: transcripts,
          language: language,
          position: videoPositions(session),
          stillPlaying: () =>
              session.current?.canonicalUrl == item.canonicalUrl,
          onMoment: session.seek,
          onClose: close,
          onRead: (shown) => openReading(
            context,
            title: item.title,
            byline: item.uploader,
            transcript: shown,
            onMoment: session.seek,
            playback: ReadingPlayback(
              positions: () => videoPositions(session),
              seek: session.seek,
              stillPlaying: () =>
                  session.current?.canonicalUrl == item.canonicalUrl,
              playing: videoPlaying(session),
              playPause: session.playPause,
            ),
          ),
        );
        if (chapters.isEmpty) return transcript;
        return TranscriptPanelTabs(
          transcript: transcript,
          chapters: chapters,
          session: session,
          onClose: close,
        );
      },
    );
  };
}

/// The transcript as a tab beside the audio player on a tablet, for the
/// items that have one. It never closes itself when the queue moves: the
/// tab is rebuilt for the next item instead.
MTVideoPanel? Function(PlaylistItem item) audioTranscriptPanels(
  BuildContext context,
  MTAudioHandler handler,
) {
  final container = ProviderScope.containerOf(context, listen: false);
  final label = context.mtl.transcript;
  return (item) {
    final transcripts = _transcriptsOf(container, item.canonicalUrl);
    if (transcripts.isEmpty) return null;
    return MTVideoPanel(
      icon: Icons.subject_rounded,
      label: label,
      builder: (context, close) => TranscriptSheet(
        title: item.title,
        query: '',
        transcripts: transcripts,
        language: container.read(subtitlePrefsProvider).language,
        position: handler.positionStream,
        onMoment: handler.seek,
        onClose: close,
        onRead: (shown) => openReading(
          context,
          title: item.title,
          byline: item.uploader,
          transcript: shown,
          onMoment: handler.seek,
          playback: ReadingPlayback(
            positions: () => handler.positionStream,
            seek: handler.seek,
            stillPlaying: () =>
                handler.currentItem?.canonicalUrl == item.canonicalUrl,
            playing: handler.playbackState.map((state) => state.playing),
            playPause: () => _audioPlayPause(handler),
          ),
        ),
      ),
    );
  };
}

/// A video's position, sampled: the session tells its listeners of much
/// more than the time, and a quarter second is finer than any caption.
Stream<Duration> videoPositions(MTVideoSession session) =>
    Stream.periodic(const Duration(milliseconds: 250), (_) => session.position);

/// Whether a video plays, sampled as its position is.
Stream<bool> videoPlaying(MTVideoSession session) => Stream.periodic(
  const Duration(milliseconds: 250),
  (_) => session.isPlaying,
).distinct();

void _audioPlayPause(MTAudioHandler handler) =>
    handler.playbackState.value.playing ? handler.pause() : handler.play();

void _openFollowing(
  BuildContext context,
  PlaylistItem playing, {
  required Stream<Duration> Function() positions,
  required bool Function() stillPlaying,
  required Future<void> Function(Duration) seek,
  Stream<bool>? isPlaying,
  VoidCallback? playPause,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final transcripts = _transcriptsOf(container, playing.canonicalUrl);
  if (transcripts.isEmpty) return;
  _open(
    context,
    (_) => TranscriptSheet(
      title: playing.title,
      query: '',
      transcripts: transcripts,
      language: container.read(subtitlePrefsProvider).language,
      position: positions(),
      stillPlaying: stillPlaying,
      onMoment: seek,
      onRead: (shown) => openReading(
        context,
        title: playing.title,
        byline: playing.uploader,
        transcript: shown,
        onMoment: seek,
        playback: ReadingPlayback(
          positions: positions,
          seek: seek,
          stillPlaying: stillPlaying,
          playing: isPlaying,
          playPause: playPause,
        ),
      ),
    ),
  );
}

List<Transcript> _transcriptsOf(ProviderContainer container, String url) =>
    container.read(transcriptIndexProvider).valueOrNull?.transcriptsFor(url) ??
    const [];

void _open(BuildContext context, WidgetBuilder builder) {
  showMTSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    // Keeps the handle out of the camera cutout; the bottom is padded by
    // the sheet itself, since this protects the top only.
    useSafeArea: true,
    builder: builder,
  );
}
