import 'package:media_kit/media_kit.dart';

import '../data/volume.dart';

/// The engine's own level (0 to 100).
class MediaKitVolume implements VolumeControl {
  MediaKitVolume(this._player);

  final Player _player;

  @override
  double get level => _player.state.volume;

  @override
  Future<void> setLevel(double level) => _player.setVolume(level);
}
