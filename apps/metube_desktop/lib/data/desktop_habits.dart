import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';

/// "Keep playing in the tray when the window closes" as start-up read it;
/// main puts in the saved choice. **Off until chosen**, so closing the
/// window closes the app, as it always did.
final initialCloseToTrayProvider = Provider<bool>((ref) => false);

/// What turning it on or off does beyond saving it: main puts the icon by
/// the clock and changes what the window's close does.
final closeToTrayHookProvider = Provider<void Function(bool on)>(
  (ref) => (_) {},
);

final closeToTrayProvider = NotifierProvider<CloseToTray, bool>(
  CloseToTray.new,
);

class CloseToTray extends Notifier<bool> {
  static const key = 'ember_tray_on_close';

  @override
  bool build() => ref.read(initialCloseToTrayProvider);

  Future<void> set(bool on) async {
    state = on;
    ref.read(closeToTrayHookProvider)(on);
    final store = ref.read(keyValueStoreProvider);
    await ref.read(prefsMutexProvider).run(() => store.setBool(key, on));
  }
}

/// What turning a habit on or off asks of Windows; true when Windows took
/// it (another program may hold the same key). Main puts Windows' in.
typedef HabitHook = Future<bool> Function(bool on);

/// "Start with Windows", as Windows' own start-up list says at start-up:
/// the user can take the app off it in Task Manager, so that list, not a
/// saved choice, is the truth. Off until chosen.
final initialStartWithWindowsProvider = Provider<bool>((ref) => false);

final startWithWindowsHookProvider = Provider<HabitHook>(
  (ref) =>
      (_) async => true,
);

final startWithWindowsProvider = NotifierProvider<StartWithWindows, bool>(
  StartWithWindows.new,
);

class StartWithWindows extends Notifier<bool> {
  @override
  bool build() => ref.read(initialStartWithWindowsProvider);

  /// False when Windows refused; the switch stays as it was.
  Future<bool> set(bool on) async {
    final took = await ref.read(startWithWindowsHookProvider)(on);
    if (took) state = on;
    return took;
  }
}

/// "Play and pause from any app": a key combination that works with the
/// window behind others, for keyboards without a play key. Off until
/// chosen, and registered again at each start while on.
final initialGlobalPlayKeyProvider = Provider<bool>((ref) => false);

final globalPlayKeyHookProvider = Provider<HabitHook>(
  (ref) =>
      (_) async => true,
);

final globalPlayKeyProvider = NotifierProvider<GlobalPlayKey, bool>(
  GlobalPlayKey.new,
);

class GlobalPlayKey extends Notifier<bool> {
  static const key = 'ember_global_play_key';

  /// The combination, as the keyboard prints it.
  static const label = 'Ctrl+Alt+Space';

  @override
  bool build() => ref.read(initialGlobalPlayKeyProvider);

  /// False when another program holds the combination; it stays off.
  Future<bool> set(bool on) async {
    final took = await ref.read(globalPlayKeyHookProvider)(on);
    if (!took) return false;
    state = on;
    final store = ref.read(keyValueStoreProvider);
    await ref.read(prefsMutexProvider).run(() => store.setBool(key, on));
    return true;
  }
}
