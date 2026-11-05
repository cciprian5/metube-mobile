import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mt_media/mt_media.dart';

import 'one_player_guard.dart';
import 'player_trace.dart';

export 'one_player_guard.dart';

/// [MediaPlayerPort] over a media_kit [Player], so the shared session
/// player drives libmpv exactly as it drives just_audio on the phones.
class MediaKitPort implements MediaPlayerPort {
  MediaKitPort._(this._player, this._trace, [this._askEngine]) {
    final s = _player.stream;
    _subs
      ..add(s.playing.listen((_) => _changed()))
      ..add(s.buffering.listen((_) => _changed()))
      ..add(s.duration.listen((_) => _changed()))
      ..add(s.rate.listen((_) => _changed()))
      ..add(s.completed.listen(_onCompleted))
      ..add(s.error.listen(_onEngineError))
      ..add(s.log.listen(_onLog));
    unawaited(_reconnectDroppedStreams());
  }

  /// The one player of the app; a second call throws.
  factory MediaKitPort.create({PlayerTrace? trace}) {
    OnePlayerGuard.claim();
    return MediaKitPort._(
      // Warnings too, for the log: a fault on another computer is seen
      // only through it.
      Player(
        configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
      ),
      trace ?? silentTrace,
    );
  }

  /// Over an engine a test drives; [stillPlaying] answers what mpv would.
  @visibleForTesting
  factory MediaKitPort.over(
    Player player, {
    required Future<bool> Function() stillPlaying,
  }) => MediaKitPort._(player, silentTrace, stillPlaying);

  final Player _player;
  final PlayerTrace _trace;
  final Future<bool> Function()? _askEngine;
  final _repeats = LogRepeats();
  Timer? _judging;
  bool _streaming = false;

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

  /// **mpv's own reconnection for a dropped stream**: off by default in
  /// ffmpeg, so a connection the network or a tunnel cut ended the clip
  /// where it was.
  Future<void> _reconnectDroppedStreams() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    await native.setProperty(
      'stream-lavf-o',
      'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
          'reconnect_delay_max=5',
    );
  }

  void _onLog(PlayerLog log) {
    if (log.level != 'error' && log.level != 'warn') return;
    // media_kit asks every start for an option this mpv lacks: noise.
    if (log.text.contains('property not found')) return;
    final line = _repeats.pass('${log.prefix}: ${log.text}');
    if (line != null) _trace('mpv $line', problem: log.level == 'error');
  }

  /// **The end of a stream well before its length is a failure**, not
  /// the clip ending: mpv reads a dropped connection as the end of the
  /// file, and the queue moved on (or a looping short started over) from
  /// the middle.
  void _onCompleted(bool done) {
    final length = _player.state.duration;
    final at = _player.state.position;
    if (done &&
        _streaming &&
        length > Duration.zero &&
        length - at > earlyEnd) {
      _trace(
        'stream ended early at ${traceClock(at)} of ${traceClock(length)}',
        problem: true,
      );
      _changed();
      if (!_errors.isClosed) _errors.add('ended early');
      return;
    }
    if (done) _trace('ended at ${traceClock(at)} of ${traceClock(length)}');
    _changed(completed: done);
  }

  /// How far from its length a stream may stop and still count as ended.
  static const Duration earlyEnd = Duration(seconds: 5);

  /// **An error message is not a failure until playback stops**: media_kit
  /// passes on every error line mpv logs, and most (a frame the decoder
  /// dropped, a hardware decoder falling back to software) leave the clip
  /// playing. Treated as failures, they reloaded the clip from the start.
  void _onEngineError(String error) {
    if (_loading) return; // The load in progress judges its own.
    _judging ??= Timer(judgeAfter, () => unawaited(_judge(error)));
  }

  /// How long after an error the player is looked at again.
  static const Duration judgeAfter = Duration(seconds: 2);

  Future<void> _judge(String error) async {
    _judging = null;
    if (_loading || await (_askEngine ?? _stillPlaying)()) return;
    _trace('playback failed: $error', problem: true);
    if (!_errors.isClosed) _errors.add(error);
  }

  Future<bool> _stillPlaying() async {
    final native = _player.platform;
    if (native is! NativePlayer) return true;
    final idle = await native.getProperty('idle-active');
    final path = await native.getProperty('path');
    return idle != 'yes' && path.isNotEmpty;
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
    _judging?.cancel();
    _judging = null;
    _streaming = !source.isLocal;
    _changed();
    final resource = source.isLocal
        ? source.uri.toFilePath()
        : source.uri.toString();
    final clock = Stopwatch()..start();
    _trace(
      'open ${source.isLocal ? 'file' : 'stream'} ${traceKindOf(resource)}'
      '${initialPosition > Duration.zero ? ' at ${traceClock(initialPosition)}' : ''}',
    );
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
      _trace(
        'loaded in ${clock.elapsedMilliseconds} ms${await tracePicture(_player)}',
      );
    } on Object catch (e) {
      _trace('load failed: $e', problem: true);
      rethrow;
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
    _judging?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _events.close();
    await _states.close();
    await _errors.close();
  }
}
