import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';

/// A cover kept on this computer for the clip at [canonicalUrl], whose
/// queue entry names [artwork] (often nothing: the library has it), as a
/// file Windows can read itself, or null.
typedef CoverFile = Future<String?> Function(
  String canonicalUrl,
  String? artwork,
);

/// The bridge to Windows' places, so the app can hand it [CoverFile] once
/// the server is known. Overridden in main; null in tests.
final systemMediaBridgeProvider = Provider<SystemMediaBridge?>((ref) => null);

/// What Windows shows of the clip playing, in its media flyout, the tray
/// menu and the taskbar preview.
class SystemNowPlaying {
  const SystemNowPlaying({
    required this.title,
    this.artist,
    this.thumbnail,
    this.canonicalUrl,
    this.artwork,
    required this.playing,
    required this.canNext,
    required this.canPrevious,
  });

  final String title;
  final String? artist;

  /// A picture Windows may fetch on its own: see [publicThumbnail], or a
  /// cover file on this computer.
  final String? thumbnail;

  /// The clip, and its own picture as the queue names it (an address or a
  /// path), which is never handed to Windows as it is: see
  /// [SystemMediaBridge.coverFile].
  final String? canonicalUrl;
  final String? artwork;
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
      canonicalUrl: item.canonicalUrl,
      artwork: item.artworkUrl,
      playing: state.playing,
      canNext: state.index < state.items.length - 1,
      canPrevious: state.items.length > 1,
    );
  }

  /// The same, with [file] (a `file:` address) for its picture.
  SystemNowPlaying withCover(String file) => SystemNowPlaying(
    title: title,
    artist: artist,
    thumbnail: file,
    canonicalUrl: canonicalUrl,
    artwork: artwork,
    playing: playing,
    canNext: canNext,
    canPrevious: canPrevious,
  );

  @override
  bool operator ==(Object other) =>
      other is SystemNowPlaying &&
      other.title == title &&
      other.artist == artist &&
      other.thumbnail == thumbnail &&
      other.canonicalUrl == canonicalUrl &&
      other.artwork == artwork &&
      other.playing == playing &&
      other.canNext == canNext &&
      other.canPrevious == canPrevious;

  @override
  int get hashCode => Object.hash(
    title,
    artist,
    thumbnail,
    canonicalUrl,
    artwork,
    playing,
    canNext,
    canPrevious,
  );
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

  /// **The cover of a clip whose picture Windows may not fetch itself**
  /// (one on the user's server, which needs the password): the copy
  /// already saved on this computer. Without it the flyout kept showing
  /// the cover of the last clip that had a public one.
  CoverFile? coverFile;
  ({String clip, String file})? _cover;
  String? _finding;

  void _show(MTPlayerState state) {
    var now = SystemNowPlaying.of(state);
    if (now case SystemNowPlaying(thumbnail: null, canonicalUrl: final url?)) {
      if (_cover?.clip == url) {
        now = now.withCover(_cover!.file);
      } else if (coverFile != null) {
        unawaited(_findCover(url, now.artwork));
      }
    }
    // A position tick repeats the same state; Windows needs telling once.
    if (!_first && now == _shown) return;
    _first = false;
    _shown = now;
    for (final surface in surfaces) {
      unawaited(surface.show(now));
    }
  }

  Future<void> _findCover(String url, String? artwork) async {
    if (_finding == url) return;
    _finding = url;
    String? file;
    try {
      file = await coverFile!(url, artwork);
    } on Object {
      // No cover then: the flyout shows the app's own picture.
    }
    _finding = null;
    if (file == null) return;
    _cover = (clip: url, file: Uri.file(file).toString());
    _show(player.state);
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
