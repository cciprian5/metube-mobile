import 'package:mt_media/mt_media.dart';

/// A player frozen in one state, for the widget previews: it plays
/// nothing and ignores every command, so a preview needs no engine.
class StillPlayer implements MTPlayer {
  StillPlayer([
    this.state = const MTPlayerState(),
    this.position = Duration.zero,
  ]);

  @override
  final MTPlayerState state;
  @override
  final Duration position;

  @override
  Stream<MTPlayerState> get states => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> loadPreferences() async {}
  @override
  Future<void> playItems(
    List<PlaylistItem> items, {
    int startIndex = 0,
    String? playlistId,
    String? playlistName,
    bool autoPlay = true,
  }) async {}
  @override
  Future<bool> restoreSession() async => false;
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> skipToNext() async {}
  @override
  Future<void> skipToPrevious() async {}
  @override
  Future<void> skipToQueueItem(int index) async {}
  @override
  Future<void> moveQueueItem(int from, int to) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> setPlayMode(PlayMode mode) async {}
  @override
  Future<void> setShuffle(bool value) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> persist() async {}
  @override
  Future<void> dispose() async {}
}
