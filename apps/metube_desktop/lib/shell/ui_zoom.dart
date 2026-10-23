import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';
import '../platform/window_placement.dart';
import 'shell_state.dart';

/// The interface sizes on offer, as in a browser's zoom: Ember alone grows
/// or shrinks, on top of whatever Windows' own display scale is.
const List<double> uiZoomSteps = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5];

/// The smallest window at [zoom]: the 100% minimum, scaled with the rest.
Size minimumWindowAt(double zoom) => minimumWindowSize * zoom;

/// Whether a window at [zoom] can fit in [workArea], the screen minus the
/// taskbar. Unknown (null) fits, so nothing is held back without a reason.
bool zoomFits(double zoom, Size? workArea) {
  if (workArea == null) return true;
  final needed = minimumWindowAt(zoom);
  return needed.width <= workArea.width && needed.height <= workArea.height;
}

/// The largest step no larger than [wanted] that fits [workArea], or the
/// smallest step when none does.
///
/// **Why this exists:** a 1366x768 laptop at Windows' 125% leaves about
/// 1093x566 above the taskbar, shorter than the 600 a window needs at
/// 100%, so the player bar would sit under the taskbar. At 90% it fits.
double fittingZoom(double wanted, Size? workArea) {
  for (final step in uiZoomSteps.reversed) {
    if (step <= wanted && zoomFits(step, workArea)) return step;
  }
  return uiZoomSteps.first;
}

/// The interface size, and whether Ember just chose it because the one
/// asked for no longer fits; the shell says so once, then [acknowledge]s.
class UiZoom {
  const UiZoom(this.value, {this.lowered = false});

  final double value;
  final bool lowered;

  /// As a person reads it: 90%, 125%.
  String get percent => '${(value * 100).round()}%';

  @override
  bool operator ==(Object other) =>
      other is UiZoom && other.value == value && other.lowered == lowered;

  @override
  int get hashCode => Object.hash(value, lowered);
}

/// Reads and writes the interface size, per computer and never synced:
/// a wide monitor and a laptop want different answers.
class UiZoomStore {
  UiZoomStore({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const key = 'ember_ui_zoom';

  /// Anything unknown reads as 100%.
  Future<double> read() async {
    final value = double.tryParse(await store.getString(key) ?? '');
    return uiZoomSteps.contains(value) ? value! : 1.0;
  }

  Future<void> write(double zoom) =>
      mutex.run(() => store.setString(key, '$zoom'));
}

final uiZoomStoreProvider = Provider(
  (ref) => UiZoomStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// The interface size at start-up, already fitted to the screen the window
/// opened on; overridden in main, so the first frame has it.
final initialUiZoomProvider = Provider<UiZoom>((ref) => const UiZoom(1.0));

/// The interface size, held to what fits the window's screen: a step that
/// does not fit is refused, and moving to a smaller screen steps down.
final uiZoomProvider = NotifierProvider<UiZoomNotifier, UiZoom>(
  UiZoomNotifier.new,
);

class UiZoomNotifier extends Notifier<UiZoom> {
  @override
  UiZoom build() {
    final area = ref.watch(windowControlsProvider).workArea;
    area.addListener(_refit);
    ref.onDispose(() => area.removeListener(_refit));
    return ref.watch(initialUiZoomProvider);
  }

  Size? get _area => ref.read(windowControlsProvider).workArea.value;

  /// Whether [zoom] can be chosen on this screen; the settings dim the
  /// others.
  bool fits(double zoom) => zoomFits(zoom, _area);

  void zoomIn() {
    final i = uiZoomSteps.indexOf(state.value);
    if (i < uiZoomSteps.length - 1) set(uiZoomSteps[i + 1]);
  }

  void zoomOut() {
    final i = uiZoomSteps.indexOf(state.value);
    if (i > 0) set(uiZoomSteps[i - 1]);
  }

  void reset() => set(fittingZoom(1.0, _area));

  /// Chooses [zoom], if it fits.
  void set(double zoom) {
    if (zoom == state.value || !fits(zoom)) return;
    _apply(UiZoom(zoom));
  }

  /// The notice about a size Ember chose has been shown.
  void acknowledge() {
    if (state.lowered) state = UiZoom(state.value);
  }

  void _refit() {
    if (fits(state.value)) return;
    _apply(UiZoom(fittingZoom(state.value, _area), lowered: true));
  }

  void _apply(UiZoom next) {
    state = next;
    ref.read(windowControlsProvider).setMinimumSize(minimumWindowAt(next.value));
    unawaited(ref.read(uiZoomStoreProvider).write(next.value));
  }
}
