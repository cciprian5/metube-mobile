import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Where captions read the time: a player's position, whether it runs, and
/// how fast, telling its listeners on each report. The phones' video
/// player is one; the Windows app hands its own.
abstract interface class MTCaptionClock implements Listenable {
  Duration get position;

  /// Playing and not waiting for data: time moves between two reports.
  bool get running;

  double get speed;
}

/// The phones' [VideoPlayerController] as a caption clock.
class VideoCaptionClock implements MTCaptionClock {
  VideoCaptionClock(this.controller);

  final VideoPlayerController controller;

  @override
  Duration get position => controller.value.position;

  @override
  bool get running =>
      controller.value.isPlaying && !controller.value.isBuffering;

  @override
  double get speed => controller.value.playbackSpeed;

  @override
  void addListener(VoidCallback listener) => controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      controller.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is VideoCaptionClock && other.controller == controller;

  @override
  int get hashCode => controller.hashCode;
}
