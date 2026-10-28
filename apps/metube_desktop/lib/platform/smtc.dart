import 'dart:async';

import 'package:smtc_windows/smtc_windows.dart';

import '../data/system_media.dart';
import '../identity.dart';

/// **Windows' media flyout and the keyboard's media keys** (System Media
/// Transport Controls): the clip's title, channel and cover by the volume
/// and the lock screen, and play, pause, next and previous from the keys.
class SmtcSurface implements SystemMediaSurface {
  SmtcSurface._(this._smtc);

  final SMTCWindows _smtc;
  final _buttons = StreamController<SystemMediaButton>.broadcast();
  StreamSubscription<PressedButton>? _presses;
  String? _shownKey;

  /// Null when Windows' media service cannot be reached; the app plays on
  /// without it.
  static Future<SmtcSurface?> start() async {
    try {
      await SMTCWindows.initialize();
      final smtc = SMTCWindows(
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          stopEnabled: true,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
      );
      final surface = SmtcSurface._(smtc);
      surface._presses = smtc.buttonPressStream.listen(surface._onPress);
      return surface;
    } on Object {
      return null;
    }
  }

  void _onPress(PressedButton button) {
    final mapped = switch (button) {
      PressedButton.play => SystemMediaButton.play,
      PressedButton.pause => SystemMediaButton.pause,
      PressedButton.next => SystemMediaButton.next,
      PressedButton.previous => SystemMediaButton.previous,
      PressedButton.stop => SystemMediaButton.stop,
      _ => null,
    };
    if (mapped != null) _buttons.add(mapped);
  }

  @override
  Stream<SystemMediaButton> get buttons => _buttons.stream;

  @override
  Future<void> show(SystemNowPlaying? now) async {
    try {
      if (now == null) {
        _shownKey = null;
        await _smtc.disableSmtc();
        return;
      }
      // The picture is fetched again on every metadata write, so it is
      // written when the clip or its picture changes, not on every play
      // and pause. **Cleared first**: a write with no picture keeps the
      // last one, which showed the previous clip's cover by this one.
      final key = '${now.title}\n${now.thumbnail}';
      if (key != _shownKey) {
        _shownKey = key;
        await _smtc.clearMetadata();
        await _smtc.updateMetadata(
          MusicMetadata(
            title: now.title,
            artist: now.artist ?? EmberIdentity.displayName,
            thumbnail: now.thumbnail,
          ),
        );
      }
      await _smtc.setPlaybackStatus(
        now.playing ? PlaybackStatus.playing : PlaybackStatus.paused,
      );
      await _smtc.enableSmtc();
    } on Object {
      // A service that went away mid-session: the next clip tries again.
    }
  }

  @override
  Future<void> dispose() async {
    await _presses?.cancel();
    await _buttons.close();
    try {
      await _smtc.dispose();
    } on Object {
      // Already gone with the process.
    }
  }
}
