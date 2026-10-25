import 'dart:async';
import 'dart:ui';

import 'package:windows_taskbar/windows_taskbar.dart';

import '../data/system_media.dart';
import '../data/taskbar_data.dart';

/// The words the taskbar shows, in the app's language; the platform layer
/// has no context to look them up in.
typedef TaskbarWords = ({
  String previous,
  String play,
  String pause,
  String next,
  String Function(int count) downloads,
});

/// **The taskbar button**: download progress across it and their count on
/// it, and ⏮ ❚❚ ⏭ under the window's preview. Its icons follow the
/// taskbar's light or dark.
class WindowsTaskbarSurface implements SystemMediaSurface, TaskbarPort {
  WindowsTaskbarSurface(this.words);

  final TaskbarWords words;
  final _buttons = StreamController<SystemMediaButton>.broadcast();

  static const _folder = 'assets/tray/';

  /// Windows' own display language, which decides whether its taskbar is
  /// mirrored; the first of the user's languages.
  bool get _mirrored {
    final locales = PlatformDispatcher.instance.locales;
    return windowsMirrors(locales.isEmpty ? null : locales.first.languageCode);
  }

  String get _theme =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark
      ? 'dark'
      : 'light';

  ThumbnailToolbarAssetIcon _icon(String name) =>
      ThumbnailToolbarAssetIcon('$_folder${name}_$_theme.ico');

  @override
  Stream<SystemMediaButton> get buttons => _buttons.stream;

  @override
  Future<void> show(SystemNowPlaying? now) async {
    try {
      if (now == null) {
        await WindowsTaskbar.resetThumbnailToolbar();
        return;
      }
      ThumbnailToolbarButton button(
        String icon,
        String tooltip,
        SystemMediaButton press, {
        bool enabled = true,
      }) => ThumbnailToolbarButton(
        _icon(icon),
        tooltip,
        () => _buttons.add(press),
        mode: enabled ? 0 : ThumbnailToolbarButtonMode.disabled,
      );
      await WindowsTaskbar.setThumbnailToolbar(
        previewOrder(mirrored: _mirrored, [
          button(
            'prev',
            words.previous,
            SystemMediaButton.previous,
            enabled: now.canPrevious,
          ),
          now.playing
              ? button('pause', words.pause, SystemMediaButton.pause)
              : button('play_fill', words.play, SystemMediaButton.play),
          button(
            'next',
            words.next,
            SystemMediaButton.next,
            enabled: now.canNext,
          ),
        ]),
      );
    } on Object {
      // The window is not shown yet, or is closing; the next change tries
      // again.
    }
  }

  @override
  Future<void> showDownloads(TaskbarDownloads downloads) async {
    try {
      final (:count, :progress) = downloads;
      if (count == 0) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
        await WindowsTaskbar.resetOverlayIcon();
        return;
      }
      if (progress == null) {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
      } else {
        await WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
        await WindowsTaskbar.setProgress((progress * 100).round(), 100);
      }
      final badge = count > 9 ? '9plus' : '$count';
      await WindowsTaskbar.setOverlayIcon(
        ThumbnailToolbarAssetIcon('${_folder}badge_$badge.ico'),
        tooltip: words.downloads(count),
      );
    } on Object {
      // As above.
    }
  }

  @override
  Future<void> dispose() => _buttons.close();
}
