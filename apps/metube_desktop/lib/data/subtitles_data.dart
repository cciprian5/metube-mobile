import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import '../di.dart';
import 'appearance_data.dart';
import 'transcripts_data.dart';

/// Subtitles over the picture, drawn from the clip's transcript as the
/// phone draws them: off until asked for, from the CC button, the C key or
/// Settings, and kept between runs. Their size, their background and the
/// language chosen are the phone's choices too, from Settings or the
/// player.
class EmberSubtitles {
  EmberSubtitles(this._store) {
    unawaited(_load());
  }

  final KeyValueStore _store;

  /// Shared by the CC button, the key and the switch in Settings.
  final shown = ValueNotifier(false);

  /// Small, medium or large: an index into [scales].
  final size = ValueNotifier(1);

  /// Solid, faint or none: an index into [MTCaptionBackground.values].
  final background = ValueNotifier(0);

  /// The language picked, kept from clip to clip; null puts the reader's
  /// first.
  final language = ValueNotifier<String?>(null);

  static const key = 'ember_subtitles_shown';
  static const sizeKey = 'ember_subtitles_size';
  static const backgroundKey = 'ember_subtitles_background';
  static const languageKey = 'ember_subtitles_language';

  /// The phone's three sizes.
  static const scales = [0.85, 1.0, 1.25];

  double get scale => scales[size.value.clamp(0, scales.length - 1)];

  MTCaptionBackground get backdrop =>
      MTCaptionBackground.values[background.value.clamp(
        0,
        MTCaptionBackground.values.length - 1,
      )];

  Future<void> _load() async {
    shown.value = await _store.getBool(key) ?? false;
    size.value = await _store.getInt(sizeKey) ?? 1;
    background.value = await _store.getInt(backgroundKey) ?? 0;
    language.value = await _store.getString(languageKey);
    // Saved from here on; what was just read is not written back.
    shown.addListener(() => unawaited(_store.setBool(key, shown.value)));
    size.addListener(() => unawaited(_store.setInt(sizeKey, size.value)));
    background.addListener(
      () => unawaited(_store.setInt(backgroundKey, background.value)),
    );
    language.addListener(
      () => unawaited(switch (language.value) {
        final code? => _store.setString(languageKey, code),
        null => _store.remove(languageKey),
      }),
    );
  }

  void toggle() => shown.value = !shown.value;

  void dispose() {
    shown.dispose();
    size.dispose();
    background.dispose();
    language.dispose();
  }
}

final emberSubtitlesProvider = Provider<EmberSubtitles>((ref) {
  final subtitles = EmberSubtitles(ref.watch(keyValueStoreProvider));
  ref.onDispose(subtitles.dispose);
  return subtitles;
});

/// The clip's transcript as caption lines, the words timed where the
/// subtitles tell them; null with no transcript. The same list comes back
/// until the transcript changes, so the captions do not regroup on every
/// rebuild.
final captionLinesProvider =
    Provider.family<List<MTCaptionLine>?, TranscriptKey>((ref, key) {
      final transcript = ref.watch(transcriptForProvider(key)).valueOrNull;
      if (transcript == null || transcript.isEmpty) return null;
      return _linesOf(transcript);
    });

/// **Every language the clip's subtitles come in**, the reader's first,
/// then English, then the rest: what the player's switch walks, so an
/// Arabic reader goes from the Arabic to the English and back. Null with
/// no transcript at all.
final captionTracksProvider =
    Provider.family<Map<String, List<MTCaptionLine>>?, TranscriptKey>((
      ref,
      key,
    ) {
      final first = ref.watch(transcriptForProvider(key)).valueOrNull;
      final kept =
          ref
              .watch(transcriptLanguagesProvider(key.canonicalUrl))
              .valueOrNull ??
          const <Transcript>[];
      final all = [
        ?first,
        for (final t in kept)
          if (t.language != first?.language) t,
      ].where((t) => !t.isEmpty).toList();
      if (all.isEmpty) return null;
      final order = readerLanguages(ref.watch(appearanceProvider).locale);
      int rank(Transcript t) {
        final at = order.indexOf(Transcript.baseLanguage(t.language));
        return at < 0 ? order.length : at;
      }

      all.sort((a, b) => rank(a) - rank(b));
      return {for (final t in all) t.language: _linesOf(t)};
    });

List<MTCaptionLine> _linesOf(Transcript transcript) => [
  for (final s in transcript.segments)
    MTCaptionLine(
      start: s.start,
      end: s.end,
      text: s.text,
      words: switch (s.words) {
        final words? => [for (final w in words) MTCaptionWord(w.start, w.text)],
        null => null,
      },
    ),
];

/// The app's player as the captions' clock: its position on each report,
/// and whether it runs.
class PlayerCaptionClock extends ChangeNotifier implements MTCaptionClock {
  PlayerCaptionClock(this._player) {
    _subs
      ..add(_player.states.listen((_) => notifyListeners()))
      ..add(_player.positionStream.listen((_) => notifyListeners()));
  }

  final MTPlayer _player;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  Duration get position => _player.position;

  @override
  bool get running {
    final state = _player.state;
    return state.playing &&
        state.phase != MediaPlaybackState.buffering &&
        state.phase != MediaPlaybackState.loading;
  }

  @override
  double get speed => _player.state.speed;

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}
