import 'dart:async';
import 'dart:ui';

import 'package:tray_manager/tray_manager.dart';

import '../data/system_media.dart';
import '../identity.dart';

/// The words of the tray menu, in the app's language.
typedef TrayWords = ({
  String play,
  String pause,
  String next,
  String open,
  String quit,
});

/// **The icon by the clock**, there while "keep playing in the tray" is on:
/// a click opens the window, and its menu plays, pauses, skips, opens and
/// quits. Its one-colour icon follows the taskbar's light or dark.
class EmberTray with TrayListener implements SystemMediaSurface {
  EmberTray({required this.words, required this.onOpen, required this.onQuit});

  final TrayWords words;
  final VoidCallback onOpen;
  final Future<void> Function() onQuit;
  final _buttons = StreamController<SystemMediaButton>.broadcast();
  SystemNowPlaying? _now;
  var _on = false;

  static const _toggle = 'toggle';
  static const _next = 'next';
  static const _open = 'open';
  static const _quit = 'quit';

  /// Puts the icon by the clock, or takes it away.
  Future<void> setOn(bool on) async {
    if (on == _on) return;
    _on = on;
    try {
      if (!on) {
        trayManager.removeListener(this);
        await trayManager.destroy();
        return;
      }
      trayManager.addListener(this);
      final dark =
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      await trayManager.setIcon(
        'assets/tray/tray_${dark ? 'dark' : 'light'}.ico',
      );
      await _refresh();
    } on Object {
      // No tray on this desktop; the window simply closes as before.
      _on = false;
    }
  }

  @override
  Stream<SystemMediaButton> get buttons => _buttons.stream;

  @override
  Future<void> show(SystemNowPlaying? now) async {
    _now = now;
    if (_on) await _refresh();
  }

  Future<void> _refresh() async {
    final now = _now;
    try {
      await trayManager.setToolTip(
        now == null
            ? EmberIdentity.displayName
            : '${EmberIdentity.displayName} · ${now.title}',
      );
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(
              key: _toggle,
              label: now?.playing ?? false ? words.pause : words.play,
              disabled: now == null,
            ),
            MenuItem(
              key: _next,
              label: words.next,
              disabled: !(now?.canNext ?? false),
            ),
            MenuItem.separator(),
            MenuItem(key: _open, label: words.open),
            MenuItem(key: _quit, label: words.quit),
          ],
        ),
      );
    } on Object {
      // The tray went away with Explorer restarting; the next change
      // tries again.
    }
  }

  @override
  void onTrayIconMouseDown() => onOpen();

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _toggle:
        _buttons.add(SystemMediaButton.toggle);
      case _next:
        _buttons.add(SystemMediaButton.next);
      case _open:
        onOpen();
      case _quit:
        unawaited(onQuit());
    }
  }

  @override
  Future<void> dispose() async {
    await setOn(false);
    await _buttons.close();
  }
}
