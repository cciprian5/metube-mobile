import 'dart:async';

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
    MTLogger? logger,
  }) {
    // What the player did, in the diagnostic log: a clip that fails on
    // another computer can then be read there, in Settings.
    void trace(String line, {bool problem = false}) => unawaited(
      logger?.log(
        line,
        level: problem ? LogLevel.warn : LogLevel.info,
        tag: 'player',
      ),
    );
    final port = MediaKitPort.create(trace: trace);
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
        onTrace: (event) => trace(event, problem: true),
      ),
    );
  }

  /// The engine, for the video surface.
  final MediaKitPort port;

  /// What the interface, the media keys and the tray talk to.
  final MTPlayer session;
}
