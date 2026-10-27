import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';

/// The sound's level, 0 to 100, as the engine plays it. Windows' own mixer
/// sits above it; this is the app's share, as in any desktop player.
abstract class VolumeControl {
  double get level;
  Future<void> setLevel(double level);
}

/// For tests, and wherever no engine is wired.
class HeldVolume implements VolumeControl {
  HeldVolume([this.level = 100]);

  @override
  double level;

  @override
  Future<void> setLevel(double level) async => this.level = level;
}

final volumeControlProvider = Provider<VolumeControl>((ref) => HeldVolume());

final volumeProvider = NotifierProvider<VolumeLevel, double>(VolumeLevel.new);

/// The level, changed by ↑ and ↓ or the player bar's slider, and kept
/// between runs (main applies the kept one before the first clip plays).
class VolumeLevel extends Notifier<double> {
  static const key = 'ember_volume';

  /// One key press: twenty presses from silence to full.
  static const step = 5.0;

  @override
  double build() => ref.read(volumeControlProvider).level;

  /// Up for a positive [direction], down for a negative one; held at the
  /// ends.
  Future<void> nudge(int direction) =>
      set((state + direction.sign * step).clamp(0.0, 100.0));

  /// The level from the player bar's slider, from 0 to 100.
  Future<void> set(double level) async {
    final next = level.clamp(0.0, 100.0);
    if (next == state) return;
    state = next;
    await ref.read(volumeControlProvider).setLevel(next);
    final store = ref.read(keyValueStoreProvider);
    await ref
        .read(prefsMutexProvider)
        .run(() => store.setInt(key, next.round()));
  }
}
