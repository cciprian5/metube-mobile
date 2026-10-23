import '../models/play_mode.dart';
import '../models/playlist_item.dart';
import 'media_player_port.dart';

/// Everything a screen needs to draw the player, as one immutable value.
class MTPlayerState {
  const MTPlayerState({
    this.items = const [],
    this.ordered = const [],
    this.index = -1,
    this.playing = false,
    this.phase = MediaPlaybackState.idle,
    this.duration,
    this.speed = 1,
    this.mode = PlayMode.autoNext,
    this.shuffle = false,
    this.playlistId,
    this.playlistName,
  });

  /// The items in insertion order; [index] points into this list.
  final List<PlaylistItem> items;

  /// The same items in the order they will play, for "up next".
  final List<PlaylistItem> ordered;
  final int index;
  final bool playing;
  final MediaPlaybackState phase;
  final Duration? duration;
  final double speed;
  final PlayMode mode;
  final bool shuffle;
  final String? playlistId;
  final String? playlistName;

  PlaylistItem? get current =>
      index < 0 || index >= items.length ? null : items[index];

  /// No session: nothing to show in the player bar.
  bool get isEmpty => items.isEmpty;
}

/// The player as the interface sees it, **with no playback package in
/// sight**: the Windows app drives it over media_kit, and a test over a
/// fake engine. The system media controls, the tray and the taskbar read
/// [states] and call these commands; none of them knows what plays.
abstract interface class MTPlayer {
  MTPlayerState get state;
  Stream<MTPlayerState> get states;

  Duration get position;
  Stream<Duration> get positionStream;

  /// The saved speed and play mode, once at start-up.
  Future<void> loadPreferences();

  /// Plays the list that was on screen at the moment of the tap.
  Future<void> playItems(
    List<PlaylistItem> items, {
    int startIndex = 0,
    String? playlistId,
    String? playlistName,
    bool autoPlay = true,
  });

  /// Brings back the last session without playing it; false when there is
  /// none.
  Future<bool> restoreSession();

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();

  /// [index] is an index into [MTPlayerState.items].
  Future<void> skipToQueueItem(int index);
  Future<void> setSpeed(double speed);
  Future<void> setPlayMode(PlayMode mode);
  Future<void> setShuffle(bool value);

  /// Ends the session and forgets it.
  Future<void> stop();

  /// Saves the position and the session now.
  Future<void> persist();

  Future<void> dispose();
}
