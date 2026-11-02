import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// The players on screen and whether each is playing: leaving the app
  /// enters picture in picture while any of them plays.
  final _players = <Object, ({bool playing, double? aspect})>{};

  /// Android keeps the window between these shapes.
  static const _widest = 2.39;

  /// Moves the window to a corner now, shaped like the picture.
  Future<void> enter({double? aspect}) =>
      _call('enter', {'aspect': _shape(aspect)});

  /// Tells whether player [owner] is playing, and how its picture is
  /// shaped, while it is on screen.
  void attach(Object owner, {required bool playing, double? aspect}) {
    _players[owner] = (playing: playing, aspect: aspect);
    _update();
  }

  /// [owner] has left the screen.
  void detach(Object owner) {
    if (_players.remove(owner) != null) _update();
  }

  bool _auto = false;
  double? _aspect;

  void _update() {
    final playing = _players.values.where((p) => p.playing).firstOrNull;
    final auto = enabled.value && playing != null;
    final aspect = _shape(playing?.aspect);
    if (auto == _auto && aspect == _aspect) return;
    _auto = auto;
    _aspect = aspect;
    _call('setAuto', {'on': auto, 'aspect': aspect});
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
        if (call.method == 'changed') active.value = call.arguments == true;
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
    _auto = false;
    _aspect = null;
    enabled.value = false;
    active.value = false;
  }
}
