import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

/// Overridden in main with the media_kit surface.
final videoSurfaceProvider = Provider<VideoSurface>(
  (ref) => InertVideoSurface(),
);
