import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../identity.dart';
import '../shell/ui_zoom.dart';
import 'window_placement.dart';

/// The main window: opened where it was left, saved whenever it moves or
/// resizes, and closed only after [beforeClose] has run.
class EmberWindow with WindowListener {
  EmberWindow._(this._placements, this._beforeClose);

  final WindowPlacementStore _placements;
  final Future<void> Function() _beforeClose;

  /// The interface size the window opened at: the one asked for, or a
  /// smaller one when that does not fit the screen it opened on.
  double zoom = 1.0;
  Rect? _normal;
  Timer? _saveSoon;

  /// Longest wait for [beforeClose]: a stuck save must not leave a window
  /// that refuses to close.
  static const closeBudget = Duration(seconds: 2);

  /// Shows the window at the interface size [zoom], or the largest that
  /// fits the screen it opens on. [beforeClose] runs when the user closes
  /// it, so the playback position and queue are written first.
  static Future<EmberWindow> open({
    required WindowPlacementStore placements,
    required Future<void> Function() beforeClose,
    required double zoom,
  }) async {
    await windowManager.ensureInitialized();
    final window = EmberWindow._(placements, beforeClose);
    final saved = await placements.read();
    final areas = [
      for (final d in await screenRetriever.getAllDisplays()) workAreaOf(d),
    ];
    final primary = workAreaOf(await screenRetriever.getPrimaryDisplay());
    Rect place(double zoom) => placeWindow(
      saved: saved,
      workAreas: areas,
      primary: primary,
      minimum: minimumWindowAt(zoom),
    );
    var bounds = place(zoom);
    window.zoom = fittingZoom(
      zoom,
      (workAreaHolding(bounds, areas) ?? primary).size,
    );
    if (window.zoom != zoom) bounds = place(window.zoom);
    window._normal = bounds;
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: bounds.size,
        minimumSize: minimumWindowAt(window.zoom),
        title: EmberIdentity.displayName,
        // The shell draws its own title bar on the cream paper.
        titleBarStyle: TitleBarStyle.hidden,
      ),
      () async {
        await windowManager.setBounds(bounds);
        if (saved?.maximized ?? false) await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
      },
    );
    await windowManager.setPreventClose(true);
    windowManager.addListener(window);
    return window;
  }

  /// Moves and resizes arrive as a stream while dragging; one write after
  /// they settle is enough.
  void _scheduleSave() {
    _saveSoon?.cancel();
    _saveSoon = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_save()),
    );
  }

  Future<void> _save() async {
    final maximized = await windowManager.isMaximized();
    // While maximized the window reports the screen's bounds; the normal
    // ones from before are what un-maximizing should return to.
    // Nor full screen: those bounds are the screen's, and the next start
    // would open a window the size of it.
    if (!maximized &&
        !await windowManager.isMinimized() &&
        !await windowManager.isFullScreen()) {
      _normal = await windowManager.getBounds();
    }
    final normal = _normal;
    if (normal == null) return;
    await _placements.write(
      WindowPlacement(bounds: normal, maximized: maximized),
    );
  }

  @override
  void onWindowMoved() => _scheduleSave();
  @override
  void onWindowResized() => _scheduleSave();
  @override
  void onWindowMaximize() => _scheduleSave();
  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  Future<void> onWindowClose() async {
    _saveSoon?.cancel();
    try {
      await Future.wait([_save(), _beforeClose()]).timeout(closeBudget);
    } catch (_) {
      // Whatever failed or hung, the window still closes: the periodic
      // save has already kept all but the last few seconds.
    } finally {
      // **Closed the ordinary way, never with `destroy()`** (measured: 17
      // seconds to exit against 0.2). `destroy()` only ends the message
      // loop, so the engine and the player are torn down after the runner
      // has already released COM, and that teardown stalls. Letting the
      // close through destroys the window first, as without this handler.
      windowManager.removeListener(this);
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }
}

/// The part of [display] a window may use: the screen minus the taskbar.
Rect workAreaOf(Display display) {
  final origin = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;
  return origin & size;
}
