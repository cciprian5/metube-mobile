import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart' show MediaQuality;
import 'package:mt_ui/mt_ui.dart';

/// Where the playing clip's picture comes from. The pages know only this,
/// so they can be pumped in a test with no engine; the media_kit surface
/// lives in `platform/`.
///
/// **One surface for the one player**: it shows whatever the session plays,
/// and never starts a player of its own.
abstract interface class VideoSurface {
  /// The picture, letterboxed in whatever box it is given.
  Widget build(BuildContext context);

  /// Plays the sound alone, with no picture decoded, or the picture again.
  Future<void> setAudioOnly(bool on);

  /// The playing picture's size in pixels as decoded, so the clip page can
  /// say the quality that actually plays; null with no picture.
  ValueListenable<Size?> get pictureSize;

  /// What the playing file is, as the engine decodes it: the picture's
  /// size, codec and frame rate, and the sound's. The phone reads this
  /// from the file's header; here the one engine already knows it. Null
  /// with nothing loaded.
  Future<MediaQuality?> quality();
}

/// A dark box in place of the picture: tests, previews and the gallery.
class InertVideoSurface implements VideoSurface {
  /// Every call, in order, for tests to read.
  final List<String> calls = [];

  static const pictureKey = ValueKey('inert video picture');

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(key: pictureKey, color: MTPalette.fullscreenScrim);

  @override
  Future<void> setAudioOnly(bool on) async => calls.add('audioOnly $on');

  /// Set by a test as if a picture of that size played.
  @override
  final ValueNotifier<Size?> pictureSize = ValueNotifier(null);

  /// Set by a test as what the engine would say.
  MediaQuality? playing;

  @override
  Future<MediaQuality?> quality() async => playing;
}

/// Overridden in main with the media_kit surface.
final videoSurfaceProvider = Provider<VideoSurface>(
  (ref) => InertVideoSurface(),
);
