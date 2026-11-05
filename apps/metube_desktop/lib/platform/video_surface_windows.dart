import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mt_media/mt_media.dart' show MediaQuality;
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
  MediaKitVideoSurface(this._player) : _controller = VideoController(_player) {
    // Made once with the player and kept as long as it, as the controller.
    _player.stream.width.listen((_) => _measure());
    _player.stream.height.listen((_) => _measure());
  }

  final Player _player;
  final VideoController _controller;

  @override
  final ValueNotifier<Size?> pictureSize = ValueNotifier(null);

  void _measure() {
    final width = _player.state.width;
    final height = _player.state.height;
    pictureSize.value = width == null || height == null || height == 0
        ? null
        : Size(width.toDouble(), height.toDouble());
  }

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

  @override
  Future<MediaQuality?> quality() async {
    final native = _player.platform;
    if (native is! NativePlayer) return null;
    // A clip that has only just started may still be answered for by the
    // file before it, so it is given a moment to open.
    if (_player.state.position < const Duration(milliseconds: 1500)) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    Future<String> read(String name) async {
      try {
        return await native.getProperty(name);
      } on Object {
        return '';
      }
    }

    int? whole(String value) => switch (double.tryParse(value)) {
      final n? when n > 0 => n.round(),
      _ => null,
    };
    final video = await read('video-format');
    final audio = await read('audio-codec-name');
    final quality = MediaQuality(
      width: whole(await read('width')),
      height: whole(await read('height')),
      videoMime: video.isEmpty ? null : mimeForMpv(video, video: true),
      frameRate: whole(await read('container-fps')),
      audioMime: audio.isEmpty ? null : mimeForMpv(audio, video: false),
      sampleRate: whole(await read('audio-params/samplerate')),
      channels: whole(await read('audio-params/channel-count')),
    );
    return quality.isEmpty ? null : quality;
  }
}

/// mpv's name for a codec as the type the phone's header reader gives, so
/// the shared details rows name it the same way ("H.264", "AV1", "Opus").
String mimeForMpv(String codec, {required bool video}) =>
    switch (codec.toLowerCase()) {
      'h264' => 'video/avc',
      'hevc' => 'video/hevc',
      'av1' => 'video/av01',
      'vp9' => 'video/x-vnd.on2.vp9',
      'vp8' => 'video/x-vnd.on2.vp8',
      'mpeg4' => 'video/mp4v-es',
      'aac' => 'audio/mp4a-latm',
      'opus' => 'audio/opus',
      'mp3' => 'audio/mpeg',
      'vorbis' => 'audio/vorbis',
      'flac' => 'audio/flac',
      'ac3' => 'audio/ac3',
      'eac3' => 'audio/eac3',
      final other => '${video ? 'video' : 'audio'}/$other',
    };
