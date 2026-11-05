import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:win32/win32.dart';

/// **The play key from any app** (Ctrl+Alt+Space), for keyboards with no
/// play key: Windows hands it to the app with the window behind others.
class GlobalPlayHotKey {
  GlobalPlayHotKey(this.onPress);

  final void Function() onPress;

  final _hotKey = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
  );
  var _on = false;

  /// True when the key is now [on]. Turning on fails when another program
  /// holds the combination: the package does not say so, so Windows is
  /// asked first, holding the combination for a moment and letting go.
  Future<bool> set(bool on) async {
    if (on == _on) return true;
    try {
      if (on) {
        if (!_free()) return false;
        await hotKeyManager.register(_hotKey, keyDownHandler: (_) => onPress());
      } else {
        await hotKeyManager.unregister(_hotKey);
      }
      _on = on;
      return true;
    } on Object {
      return false;
    }
  }

  /// Whether Windows would give the combination to this app.
  static bool _free() {
    const probe = 0x7E3B;
    if (RegisterHotKey(NULL, probe, MOD_CONTROL | MOD_ALT, VK_SPACE) == 0) {
      return false;
    }
    UnregisterHotKey(NULL, probe);
    return true;
  }
}
