import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:mt_media/mt_media.dart';

/// Refuses a second player for the life of the app.
///
/// media_kit leaves COM uninitialised when a player is disposed, and after
/// a few disposals drag and drop stops working in the whole window. The
/// cure is to never dispose: one player opens clip after clip, and this
/// guard turns a second one into an error at the first test run instead of
/// a broken window weeks later.
abstract final class OnePlayerGuard {
  static bool _taken = false;

  static void claim() {
    if (_taken) {
      throw StateError('The Windows app keeps exactly one player.');
    }
    _taken = true;
  }

  /// For tests only: each test starts as a fresh process would.
  static void resetForTest() => _taken = false;
}

/// [MediaPlayerPort] over a media_kit [Player], so the shared session
/// player drives libmpv exactly as it drives just_audio on the phones.
class MediaKitPort implements MediaPlayerPort {
  MediaKitPort._(this._player) {
    final s = _player.stream;
    _subs
      ..add(s.playing.listen((_) => _changed()))
      ..add(s.buffering.listen((_) => _changed()))
      ..add(s.duration.listen((_) => _changed()))
      ..add(s.rate.listen((_) => _changed()))
      ..add(s.completed.listen((done) => _changed(completed: done)))
      ..add(s.error.listen(_errors.add));
  }

  /// The one player of the app; a second call throws.
  factory MediaKitPort.create() {
    OnePlayerGuard.claim();
    return MediaKitPort._(Player());
  }

  final Player _player;

  /// The engine itself, for the video surface.
  Player get player => _player;

  final _events = StreamController<void>.broadcast();
  final _states = StreamController<MediaPlaybackState>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];
  bool _loading = false;

  /// How long a source may take to report its length before the load
  /// counts as failed, which hands it to the retry-or-skip rules.
  static const Duration loadTimeout = Duration(seconds: 30);

  void _changed({bool completed = false}) {
    if (_events.isClosed) return;
    _events.add(null);
    if (completed) _states.add(MediaPlaybackState.completed);
  }

  /// **Completes once the source is loaded**, like the phone port: a load
  /// that fails or never reports a length throws, and the session player's
  /// recovery takes over.
  @override
  Future<void> setSource(
    PlaybackSource source, {
    Duration initialPosition = Duration.zero,
  }) async {
    _loading = true;
    _changed();
    final resource = source.isLocal
        ? source.uri.toFilePath()
        : source.uri.toString();
    Object? error;
    final errors = _player.stream.error.listen((e) => error ??= e);
    try {
      await _player.open(
        Media(
          resource,
          httpHeaders: source.headers,
          start: initialPosition > Duration.zero ? initialPosition : null,
        ),
        play: false,
      );
      await _untilLoaded(resource, () => error);
    } finally {
      await errors.cancel();
      _loading = false;
      _changed();
    }
  }

  /// **Asks mpv, rather than waiting for a stream event**: the duration
  /// stream stays silent when the new clip is as long as the last, which
  /// would hang the load. Loaded means mpv's current file is the one asked
  /// for and its length is known.
  Future<void> _untilLoaded(String resource, Object? Function() error) async {
    final native = _player.platform;
    final clock = Stopwatch()..start();
    while (clock.elapsed < loadTimeout) {
      if (error() case final e?) throw StateError('$e');
      if (native is NativePlayer) {
        final path = await native.getProperty('path');
        final length = double.tryParse(await native.getProperty('duration'));
        if (samePath(path, resource) && (length ?? 0) > 0) return;
      } else if (_player.state.duration > Duration.zero) {
        return;
      }
      await Future<void>.delayed(_poll);
    }
    throw TimeoutException('no length after $loadTimeout', loadTimeout);
  }

  static const Duration _poll = Duration(milliseconds: 40);

  /// Does mpv's current path name the file or address that was opened?
  ///
  /// **Not a plain comparison** (measured): media_kit hands mpv
  /// `C:/clips/a.wav` and mpv reports `\\?\C:\clips\a.wav`, the
  /// extended-length form, so an exact match never succeeds and every
  /// local file timed out. Both sides drop that prefix, use one kind of
  /// slash and one case, and are percent-decoded for addresses.
  static bool samePath(String reported, String opened) {
    String norm(String v) {
      var s = v.replaceAll(r'\', '/');
      if (s.startsWith('//?/')) s = s.substring(4);
      try {
        s = Uri.decodeFull(s);
      } on ArgumentError {
        // A name with a stray % is compared as written.
      }
      return s.toLowerCase();
    }

    return norm(reported) == norm(opened);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();

  /// Stops the clip, **never the player**: see [OnePlayerGuard].
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> setSpeed(double speed) => _player.setRate(speed);

  @override
  Duration get position => _player.state.position;
  @override
  Duration get bufferedPosition => _player.state.buffer;
  @override
  Duration? get duration {
    final d = _player.state.duration;
    return d > Duration.zero ? d : null;
  }

  @override
  double get speed => _player.state.rate;
  @override
  bool get playing => _player.state.playing;

  @override
  MediaPlaybackState get state {
    final s = _player.state;
    if (_loading) return MediaPlaybackState.loading;
    if (s.completed) return MediaPlaybackState.completed;
    if (s.buffering) return MediaPlaybackState.buffering;
    if (s.duration > Duration.zero) return MediaPlaybackState.ready;
    return MediaPlaybackState.idle;
  }

  @override
  Stream<void> get events => _events.stream;
  @override
  Stream<MediaPlaybackState> get stateStream => _states.stream;
  @override
  Stream<Duration> get positionStream => _player.stream.position;
  @override
  Stream<Object> get errors => _errors.stream;

  /// Lets go of the listeners and **keeps the player alive**: it is closed
  /// only by the process ending (see [OnePlayerGuard]).
  @override
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _events.close();
    await _states.close();
    await _errors.close();
  }
}
