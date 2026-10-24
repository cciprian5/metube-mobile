import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mt_ui/mt_ui.dart';

import '../shell/video_surface.dart';

/// [VideoSurface] over the app's single media_kit [Player].
///
/// **The video controller is made with the surface, at start-up**, not
/// when a picture is first wanted: media_kit opens its player with video
/// output off and turns it on when a controller is made, and a clip
/// already playing then gets no picture until the next one loads
/// (measured: sound and a black stage). Made once, it lives as long as the
/// player.
class MediaKitVideoSurface implements VideoSurface {
  MediaKitVideoSurface(this._player) : _controller = VideoController(_player);

  final Player _player;
  final VideoController _controller;

  @override
  Widget build(BuildContext context) => Video(
    controller: _controller,
    // Our own controls: the player bar, the page's actions and the keys.
    controls: NoVideoControls,
    fill: MTPalette.fullscreenScrim,
  );

  @override
  Future<void> setAudioOnly(bool on) =>
      _player.setVideoTrack(on ? VideoTrack.no() : VideoTrack.auto());
}
