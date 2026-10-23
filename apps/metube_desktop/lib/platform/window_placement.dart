import 'dart:convert';
import 'dart:ui';

import 'package:mt_core/mt_core.dart';

/// Where the window was when it last moved or resized, kept per computer
/// and never synced: another machine has other screens.
class WindowPlacement {
  const WindowPlacement({required this.bounds, this.maximized = false});

  /// The normal (restored) bounds, in logical pixels, even while maximized,
  /// so un-maximizing after a restart returns to them.
  final Rect bounds;
  final bool maximized;

  Map<String, Object> toJson() => {
    'x': bounds.left,
    'y': bounds.top,
    'w': bounds.width,
    'h': bounds.height,
    'max': maximized,
  };

  /// null for anything unreadable: a damaged entry costs a centred window,
  /// never a start-up crash.
  static WindowPlacement? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final x = raw['x'], y = raw['y'], w = raw['w'], h = raw['h'];
    if (x is! num || y is! num || w is! num || h is! num) return null;
    if (w <= 0 || h <= 0) return null;
    return WindowPlacement(
      bounds: Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        w.toDouble(),
        h.toDouble(),
      ),
      maximized: raw['max'] == true,
    );
  }
}

/// Reads and writes [WindowPlacement] through the one storage lock.
class WindowPlacementStore {
  WindowPlacementStore({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const key = 'ember_window_placement';

  Future<WindowPlacement?> read() async {
    final raw = await store.getString(key);
    if (raw == null) return null;
    try {
      return WindowPlacement.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(WindowPlacement placement) =>
      mutex.run(() => store.setString(key, jsonEncode(placement.toJson())));
}

/// The size of a first start, before anything was saved.
const Size firstWindowSize = Size(1280, 800);

/// The smallest window at 100% interface size.
const Size minimumWindowSize = Size(960, 600);

/// How much of the top edge must land on a screen for the window to count
/// as reachable: enough of the title bar to grab and drag back.
const Size _grabbable = Size(120, 24);

/// The bounds to open with: the saved ones when the user can still reach
/// them, otherwise centred on the primary screen.
///
/// **A saved position can be off every screen**: the monitor it was on is
/// unplugged, the laptop is undocked, or the resolution dropped. Windows
/// opens the window there anyway, invisible and impossible to drag back.
/// So the rule is the title bar: if no screen shows a grabbable piece of
/// it, the window is centred. A size larger than the work area it lands on
/// is shrunk to fit, and nothing is ever smaller than [minimum].
Rect placeWindow({
  required WindowPlacement? saved,
  required List<Rect> workAreas,
  required Rect primary,
  Size minimum = minimumWindowSize,
}) {
  final wanted = saved?.bounds;
  if (wanted != null) {
    final titleBar = Rect.fromLTWH(
      wanted.left,
      wanted.top,
      wanted.width,
      _grabbable.height,
    );
    for (final area in workAreas) {
      final seen = titleBar.intersect(area);
      if (seen.width >= _grabbable.width && seen.height >= _grabbable.height) {
        return _fit(wanted, area, minimum);
      }
    }
  }
  final size = wanted?.size ?? firstWindowSize;
  return _fit(
    Rect.fromCenter(
      center: primary.center,
      width: size.width,
      height: size.height,
    ),
    primary,
    minimum,
  );
}

/// [bounds] no larger than [area] and moved inside it where it overhangs,
/// but never below [minimum] (a tiny screen gets a window that overhangs
/// rather than a broken layout).
Rect _fit(Rect bounds, Rect area, Size minimum) {
  final w = bounds.width.clamp(
    minimum.width,
    _atLeast(area.width, minimum.width),
  );
  final h = bounds.height.clamp(
    minimum.height,
    _atLeast(area.height, minimum.height),
  );
  final left = bounds.left.clamp(
    area.left,
    _atLeast(area.right - w, area.left),
  );
  final top = bounds.top.clamp(area.top, _atLeast(area.bottom - h, area.top));
  return Rect.fromLTWH(left, top, w, h);
}

double _atLeast(double value, double floor) => value < floor ? floor : value;

/// The work area a window at [bounds] is on: the one it overlaps most, or
/// null when it overlaps none.
Rect? workAreaHolding(Rect bounds, List<Rect> workAreas) {
  Rect? best;
  var most = 0.0;
  for (final area in workAreas) {
    final seen = bounds.intersect(area);
    if (seen.width <= 0 || seen.height <= 0) continue;
    final overlap = seen.width * seen.height;
    if (overlap > most) {
      most = overlap;
      best = area;
    }
  }
  return best;
}
