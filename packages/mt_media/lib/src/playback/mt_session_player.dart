import 'dart:async';

import '../models/play_mode.dart';
import '../models/playback_source.dart';
import '../models/playlist_item.dart';
import '../stores/audio_state_store.dart';
import '../stores/playback_position_store.dart';
import '../stores/playback_prefs.dart';
import 'media_player_port.dart';
import 'mt_player.dart';
import 'playback_queue.dart';

part 'mt_session_player_flow.dart';

/// A queue player over any [MediaPlayerPort], **with no system media
/// session attached**: the Windows app's player.
///
/// It keeps the phone player's rules (`MTAudioHandler`) one for one, so a
/// playlist behaves the same on both: the play modes and shuffle, the race
/// guard, a stream retried before it is skipped, skipping a broken item
/// and stopping when the fault repeats, resuming only long items, a
/// restored session that never plays by itself, "previous" restarting the
/// song first, and the position saved every few seconds.
///
/// Two phone rules are left out because a computer has no use for them:
/// the paused auto-stop (it frees an Android wake lock) and handing the
/// output over to a separate video player (here one engine plays both).
class MTSessionPlayer implements MTPlayer {
  MTSessionPlayer({
    required this.port,
    required this.resolver,
    required this.positions,
    required this.prefs,
    required this.stateStore,
    Duration saveInterval = const Duration(seconds: 5),
    this.networkRetryBackoff = const [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
  }) {
    _subs
      ..add(port.events.listen((_) => _broadcast()))
      ..add(port.stateStream.listen(_onPhase))
      ..add(port.errors.listen((_) => unawaited(_onError())));
    _saveTimer = Timer.periodic(saveInterval, (_) => unawaited(persist()));
  }

  final MediaPlayerPort port;
  final PlaybackSourceResolver resolver;
  final PlaybackPositionStore positions;
  final PlaybackPrefs prefs;
  final AudioStateStore stateStore;

  /// The waits before retrying a failed stream, longest last; `const []`
  /// disables retrying.
  final List<Duration> networkRetryBackoff;

  /// Consecutive skips before giving up: a systemic fault fails every item,
  /// and marching silently through a hundred of them is worse than
  /// stopping plainly.
  static const int maxConsecutiveSkips = 5;

  /// How much of an item must play before its retry budget is returned, so
  /// a stream that drops every few seconds runs out of retries.
  static const Duration retryBudgetProgress = Duration(seconds: 30);

  /// Only something this long picks up where it was left: songs start from
  /// the top, lectures and episodes resume.
  static const Duration resumeMinimumLength = Duration(minutes: 10);

  /// Past this point "previous" restarts the item; within it, it goes back.
  static const Duration restartThreshold = Duration(seconds: 3);

  final List<StreamSubscription<Object?>> _subs = [];
  final _states = StreamController<MTPlayerState>.broadcast();
  PlaybackQueue _queue = PlaybackQueue(items: const []);
  PlayMode _playMode = PlayMode.autoNext;
  bool _looping = false;
  String? _playlistId;
  String? _playlistName;
  int _consecutiveErrors = 0;
  int _networkRetries = 0;
  String? _retryKey;
  Duration? _lastRetryPosition;
  Timer? _saveTimer;
  MTPlayerState _state = const MTPlayerState();

  /// The race guard: every load and every stop takes a new number, and a
  /// slower path that finds the number moved touches nothing afterwards.
  /// Without it two quick choices could play A while showing B, and a stop
  /// during a load brought the session back to life.
  int _generation = 0;

  @override
  MTPlayerState get state => _state;
  @override
  Stream<MTPlayerState> get states => _states.stream;
  @override
  Duration get position => port.position;
  @override
  Stream<Duration> get positionStream => port.positionStream;

  @override
  Future<void> loadPreferences() async {
    _playMode = await prefs.playMode();
    await port.setSpeed(await prefs.speed());
    _broadcast();
  }

  @override
  Future<void> playItems(
    List<PlaylistItem> items, {
    int startIndex = 0,
    String? playlistId,
    String? playlistName,
    bool autoPlay = true,
  }) async {
    if (items.isEmpty) return;
    // The guard starts before the preference reads, so a stop landing
    // between them is not overrun by this path.
    final generation = ++_generation;
    _playlistId = playlistId;
    _playlistName = playlistName;
    _playMode = await prefs.playMode(playlistId: playlistId);
    final shuffle = await prefs.shuffle();
    if (_isStale(generation)) return;
    _consecutiveErrors = 0;
    _queue = PlaybackQueue(items: items, index: startIndex, shuffle: shuffle);
    await _loadCurrent(autoPlay: autoPlay);
  }

  @override
  Future<bool> restoreSession() async {
    final generation = ++_generation;
    final snapshot = await stateStore.read();
    if (snapshot == null || snapshot.isEmpty) return false;
    _playlistId = snapshot.playlistId;
    _playlistName = snapshot.playlistName;
    _playMode = await prefs.playMode(playlistId: _playlistId);
    final shuffle = await prefs.shuffle();
    if (_isStale(generation)) return false;
    _queue = PlaybackQueue(
      items: snapshot.items,
      index: snapshot.index,
      shuffle: shuffle,
    );
    await _loadCurrent(autoPlay: false, startAt: snapshot.position);
    return true;
  }

  /// Play with nothing queued brings the saved list back first, so a media
  /// key never starts one stray clip with no list around it; a session the
  /// user closed, which saved none, stays closed.
  @override
  Future<void> play() async {
    if (_queue.isEmpty && !await restoreSession()) return;
    await port.play();
  }

  @override
  Future<void> pause() async {
    await port.pause();
    await persist();
  }

  @override
  Future<void> seek(Duration position) => port.seek(position);

  @override
  Future<void> skipToNext() => _skip(forward: true);

  @override
  Future<void> skipToPrevious() async {
    if (port.position > restartThreshold) {
      await port.seek(Duration.zero);
      _broadcast();
      return;
    }
    await _skip(forward: false);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _savePosition();
    if (!_queue.jumpTo(index)) return;
    await _loadCurrent(autoPlay: true);
  }

  @override
  Future<void> moveQueueItem(int from, int to) async {
    if (!_queue.moveOrdered(from, to)) return;
    _broadcast();
    await persist();
  }

  @override
  Future<void> setSpeed(double speed) async {
    final value = PlaybackSpeeds.clamp(speed);
    await port.setSpeed(value);
    await prefs.setSpeed(value);
    _broadcast();
  }

  @override
  Future<void> setPlayMode(PlayMode mode) async {
    _playMode = mode;
    await prefs.setPlayMode(mode, playlistId: _playlistId);
    _broadcast();
  }

  @override
  Future<void> setLooping(bool on) async => _looping = on;

  @override
  Future<void> setShuffle(bool value) async {
    _queue.setShuffle(value);
    await prefs.setShuffle(value);
    _broadcast();
  }

  /// Clears everything that keeps the player bar showing, the saved session
  /// included, so nothing lingers after the user closed it.
  @override
  Future<void> stop() async {
    _generation++;
    await _savePosition();
    _queue = PlaybackQueue(items: const []);
    await port.stop();
    _playlistId = null;
    _playlistName = null;
    await stateStore.clear();
    _broadcast();
  }

  /// The position plus the session snapshot, every few seconds and on
  /// pause, so a crash or a closed window loses at most that much.
  @override
  Future<void> persist() async {
    if (_queue.isEmpty) return;
    await _savePosition();
    await stateStore.write(
      AudioSessionSnapshot(
        items: _queue.items,
        index: _queue.index,
        position: port.position,
        playlistId: _playlistId,
        playlistName: _playlistName,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _states.close();
    await port.dispose();
  }

  Future<void> _skip({required bool forward}) async {
    await _savePosition();
    final moved = forward
        ? _queue.moveNext(_playMode, userInitiated: true)
        : _queue.movePrevious(_playMode);
    if (!moved) return;
    await _loadCurrent(autoPlay: true);
  }

  void _onPhase(MediaPlaybackState phase) {
    if (phase == MediaPlaybackState.completed) unawaited(_onCompleted());
  }

  void _broadcast() {
    _state = MTPlayerState(
      items: _queue.items,
      ordered: _queue.ordered,
      index: _queue.index,
      playing: port.playing,
      phase: _queue.isEmpty ? MediaPlaybackState.idle : port.state,
      duration: port.duration,
      speed: port.speed,
      mode: _playMode,
      shuffle: _queue.shuffle,
      playlistId: _playlistId,
      playlistName: _playlistName,
    );
    if (!_states.isClosed) _states.add(_state);
  }

  /// Has a newer load, or a stop, overtaken us?
  bool _isStale(int generation) => generation != _generation;
}
