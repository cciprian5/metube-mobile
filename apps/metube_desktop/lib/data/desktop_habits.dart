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
