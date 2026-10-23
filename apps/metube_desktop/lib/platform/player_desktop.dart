import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'media_kit_port.dart';

/// The Windows player: the shared session player (the phones' rules) over
/// the app's single media_kit engine.
class DesktopPlayer {
  DesktopPlayer._(this.port, this.session);

  /// Builds it once at start-up; a second call throws (see OnePlayerGuard).
  factory DesktopPlayer.create({
    required PlaybackSourceResolver resolver,
    required KeyValueStore store,
    required PrefsMutex mutex,
  }) {
    final port = MediaKitPort.create();
    return DesktopPlayer._(
      port,
      MTSessionPlayer(
        port: port,
        resolver: resolver,
        positions: PlaybackPositionStore(
          store: store,
          mutex: mutex,
          clock: DateTime.now,
        ),
        prefs: PlaybackPrefs(store: store, mutex: mutex),
        stateStore: AudioStateStore(store: store, mutex: mutex),
      ),
    );
  }

  /// The engine, for the video surface.
  final MediaKitPort port;

  /// What the interface, the media keys and the tray talk to.
  final MTPlayer session;
}
