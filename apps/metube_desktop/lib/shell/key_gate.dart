import 'package:flutter/widgets.dart';

/// **Stops a key the window already used from reaching the focus system.**
///
/// The window's keys are read on [HardwareKeyboard], which runs beside the
/// focus system rather than ahead of it: returning true there does not
/// keep the key from it. So ↑ raised the volume and then moved the focus
/// too. The window marks each key it uses here, and this gate, above the
/// navigator and below the app's own shortcuts (where the arrows become
/// "move the focus"), lets that one key go no further.
class KeyGate extends StatelessWidget {
  const KeyGate({super.key, required this.child});

  final Widget child;

  /// The keys used and not yet heard here; the same event arrives next.
  static final _used = <KeyEvent>[];

  /// Marks [event] as used by the window.
  static void used(KeyEvent event) {
    _used.add(event);
    // A key the focus system never sees (no focus at all) is not kept.
    if (_used.length > 8) _used.removeAt(0);
  }

  static KeyEventResult _hear(FocusNode _, KeyEvent event) {
    final index = _used.indexWhere((e) => identical(e, event));
    if (index < 0) return KeyEventResult.ignored;
    _used.removeAt(index);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _hear,
    child: child,
  );
}
