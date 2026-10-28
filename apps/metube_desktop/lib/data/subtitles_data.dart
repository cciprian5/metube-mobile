import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../di.dart';
import 'transcripts_data.dart';

/// Subtitles over the picture, drawn from the clip's transcript as the
/// phone draws them: off until asked for, from the CC button, the C key or
/// Settings, and kept between runs.
class EmberSubtitles {
  EmberSubtitles(this._store) {
    unawaited(_load());
  }

  final KeyValueStore _store;

  /// Shared by the CC button, the key and the switch in Settings.
  final shown = ValueNotifier(false);

  static const key = 'ember_subtitles_shown';

  Future<void> _load() async {
    shown.value = await _store.getBool(key) ?? false;
    // Saved from here on; what was just read is not written back.
    shown.addListener(() => unawaited(_store.setBool(key, shown.value)));
  }

  void toggle() => shown.value = !shown.value;

  void dispose() => shown.dispose();
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
      return [
        for (final s in transcript.segments)
          MTCaptionLine(
            start: s.start,
            end: s.end,
            text: s.text,
            words: switch (s.words) {
              final words? => [
                for (final w in words) MTCaptionWord(w.start, w.text),
              ],
              null => null,
            },
          ),
      ];
    });

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
