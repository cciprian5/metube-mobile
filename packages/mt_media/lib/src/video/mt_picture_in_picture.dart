import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mt_video_session.dart';

/// **Picture in picture** (Android): the app's window shrinks to a corner
/// of the screen with the video alone, and the user carries on elsewhere.
///
/// Off until the user turns it on in the playback settings ([enabled]):
/// then the player gains a button for it, and leaving the app while a
/// video plays enters it by itself. Each app's activity answers on the
/// `mt/pip` channel; without it (tests, the Windows app) nothing happens.
class MTPictureInPicture {
  MTPictureInPicture._() {
    enabled.addListener(_update);
  }

  static final instance = MTPictureInPicture._();

  static const _channel = MethodChannel('mt/pip');

  /// The user's choice in the playback settings, set by the app.
  final enabled = ValueNotifier(false);

  /// Whether the window is in a corner now: the player then shows the
  /// picture without its controls.
  final active = ValueNotifier(false);

  /// The players on screen: whether each is playing, how its picture is
  /// shaped, and how to play or pause it from the window's own button.
  final _players = <Object, _Player>{};

  /// Android keeps the window between these shapes.
  static const _widest = 2.39;

  /// Moves the window to a corner now, shaped like the picture.
  Future<void> enter({double? aspect}) =>
      _call('enter', {'aspect': _shape(aspect)});

  /// Tells whether player [owner] is playing, and how its picture is
  /// shaped, while it is on screen; [button] plays or pauses it from the
  /// window.
  void attach(
    Object owner, {
    required bool playing,
    double? aspect,
    MTPictureButton? button,
  }) {
    _players[owner] = (playing: playing, aspect: aspect, button: button);
    _update();
  }

  /// [owner] has left the screen.
  void detach(Object owner) {
    if (_players.remove(owner) != null) _update();
  }

  /// The player the window shows: the one playing, or else the last one on
  /// screen.
  _Player? get _current =>
      _players.values.where((p) => p.playing).firstOrNull ??
      _players.values.lastOrNull;

  /// What the activity was last told; nothing at all while turned off.
  _Sent _sent = _off;
  static const _Sent _off = (
    auto: false,
    aspect: null,
    playing: null,
    play: null,
    pause: null,
  );

  /// **The window carries its own play and pause button.** Without one
  /// Android fills it with the buttons of the app's media session, which
  /// belongs to the audio player: a video playing in the corner showed the
  /// paused audio's play button, and pressing it started the audio and
  /// stopped the video.
  void _update() {
    final current = _current;
    final _Sent sent = !enabled.value || current == null
        ? _off
        : (
            auto: current.playing,
            aspect: _shape(current.aspect),
            playing: current.button == null ? null : current.playing,
            play: current.button?.play,
            pause: current.button?.pause,
          );
    if (sent == _sent) return;
    _sent = sent;
    _call('setAuto', {
      'on': sent.auto,
      'aspect': sent.aspect,
      'playing': sent.playing,
      'play': sent.play,
      'pause': sent.pause,
    });
  }

  /// [aspect] within what Android accepts; null leaves it to the system.
  static double? _shape(double? aspect) {
    if (aspect == null || !aspect.isFinite || aspect <= 0) return null;
    return aspect.clamp(1 / _widest, _widest);
  }

  /// Whether the activity's word that the window moved is heard. Set on
  /// the first call, once Flutter's bindings are surely up.
  bool _listening = false;

  Future<void> _call(String method, Map<String, Object?> arguments) async {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'changed':
            active.value = call.arguments == true;
          case 'toggle':
            _current?.button?.toggle();
        }
      });
    }
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // No activity answers here (a test, or the computer).
    } on PlatformException catch (e) {
      debugPrint('Picture in picture: ${e.message}');
    }
  }

  /// Back to how it starts, between tests.
  @visibleForTesting
  void reset() {
    _players.clear();
    _sent = _off;
    enabled.value = false;
    active.value = false;
  }
}

/// The window's play and pause button: what it does, and its two names in
/// the user's language.
typedef MTPictureButton = ({VoidCallback toggle, String play, String pause});

typedef _Player = ({bool playing, double? aspect, MTPictureButton? button});

typedef _Sent = ({
  bool auto,
  double? aspect,
  bool? playing,
  String? play,
  String? pause,
});

/// The shape of the picture [session] plays, once its video is ready: a
/// player not ready yet reports a square, which would shape the corner
/// window wrongly.
double? mtPictureShape(MTVideoSession session) {
  final video = session.controller?.value;
  return video != null && video.isInitialized ? video.aspectRatio : null;
}
