import 'dart:async';

import 'package:mt_media/mt_media.dart';

/// What Windows shows of the clip playing, in its media flyout, the tray
/// menu and the taskbar preview.
class SystemNowPlaying {
  const SystemNowPlaying({
    required this.title,
    this.artist,
    this.thumbnail,
    required this.playing,
    required this.canNext,
    required this.canPrevious,
  });

  final String title;
  final String? artist;

  /// A picture Windows may fetch on its own: see [publicThumbnail].
  final String? thumbnail;
  final bool playing;
  final bool canNext;
  final bool canPrevious;

  /// Nothing to show while the queue is empty.
  static SystemNowPlaying? of(MTPlayerState state) {
    final item = state.current;
    if (item == null) return null;
    return SystemNowPlaying(
      title: item.title,
      artist: item.uploader,
      thumbnail: publicThumbnail(item.artworkUrl),
      playing: state.playing,
      canNext: state.index < state.items.length - 1,
      canPrevious: state.items.length > 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SystemNowPlaying &&
      other.title == title &&
      other.artist == artist &&
      other.thumbnail == thumbnail &&
      other.playing == playing &&
      other.canNext == canNext &&
      other.canPrevious == canPrevious;

  @override
  int get hashCode =>
      Object.hash(title, artist, thumbnail, playing, canNext, canPrevious);
}

/// **A cover Windows may fetch itself**, or null. Windows asks for the
/// picture with no credentials, and the address goes to the system's own
/// components: YouTube's public covers qualify, a cover on the user's own
/// server never does (it would need the password, which must not leave
/// this app, and its address is private).
String? publicThumbnail(String? url) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final youtube =
      host == 'i.ytimg.com' ||
      host.endsWith('.ytimg.com') ||
      host == 'img.youtube.com';
  return youtube ? url : null;
}

/// The right-to-left languages Flutter's own localizations know; Windows
/// shown in one of them mirrors its taskbar.
const _mirroredLanguages = {'ar', 'fa', 'he', 'ps', 'ur'};

/// Whether Windows, shown in [languageCode], mirrors its taskbar.
bool windowsMirrors(String? languageCode) =>
    _mirroredLanguages.contains(languageCode?.toLowerCase());

/// The preview's buttons in the order Windows is handed them. Media
/// controls read ⏮ ▶ ⏭ left to right in every language, as the app's own
/// player bar does; a mirrored taskbar lays them out from the right, so it
/// is handed them reversed.
List<T> previewOrder<T>(List<T> buttons, {required bool mirrored}) =>
    mirrored ? buttons.reversed.toList() : buttons;

/// A line for a menu Windows draws itself (the tray's). Those menus lay
/// text out left to right whatever the language, so "Open MeTube Ember" in
/// Arabic put the verb after the name; a right-to-left embedding makes the
/// line read in its own order.
String windowsMenuText(String text, {required bool rtl}) =>
    rtl ? '\u202B$text\u202C' : text;

/// A button pressed in one of Windows' media places.
enum SystemMediaButton { play, pause, toggle, next, previous, stop }

/// One of Windows' places for the clip playing: the media flyout and its
/// keyboard keys, the tray, the taskbar preview.
abstract class SystemMediaSurface {
  /// Shows [now], or clears the place when nothing plays.
  Future<void> show(SystemNowPlaying? now);

  /// The buttons the user pressed there.
  Stream<SystemMediaButton> get buttons;

  Future<void> dispose();
}

/// **Ties the player to Windows' places**: each shows what the player says,
/// and each button commands the player, so none of them knows the engine
/// underneath. A place that fails to start is left out; the app plays on
/// without it.
class SystemMediaBridge {
  SystemMediaBridge(this.player, this.surfaces) {
    _states = player.states.listen(_show);
    for (final surface in surfaces) {
      _presses.add(surface.buttons.listen(press));
    }
    _show(player.state);
  }

  final MTPlayer player;
  final List<SystemMediaSurface> surfaces;
  late final StreamSubscription<MTPlayerState> _states;
  final _presses = <StreamSubscription<SystemMediaButton>>[];
  SystemNowPlaying? _shown;
  var _first = true;

  void _show(MTPlayerState state) {
    final now = SystemNowPlaying.of(state);
    // A position tick repeats the same state; Windows needs telling once.
    if (!_first && now == _shown) return;
    _first = false;
    _shown = now;
    for (final surface in surfaces) {
      unawaited(surface.show(now));
    }
  }

  /// What a button does, the same from every place.
  Future<void> press(SystemMediaButton button) => switch (button) {
    SystemMediaButton.play => player.play(),
    SystemMediaButton.pause => player.pause(),
    SystemMediaButton.toggle =>
      player.state.playing ? player.pause() : player.play(),
    SystemMediaButton.next => player.skipToNext(),
    SystemMediaButton.previous => player.skipToPrevious(),
    SystemMediaButton.stop => player.pause(),
  };

  Future<void> dispose() async {
    await _states.cancel();
    for (final p in _presses) {
      await p.cancel();
    }
    for (final s in surfaces) {
      await s.dispose();
    }
  }
}
