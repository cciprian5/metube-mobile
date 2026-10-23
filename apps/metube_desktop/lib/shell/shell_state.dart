import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';
import 'shell_layout.dart';
import 'window_controls.dart';

/// The folded columns as read at start-up; overridden in main, so the
/// first frame already has them and nothing jumps.
final initialShellLayoutProvider = Provider<ShellLayout>(
  (ref) => const ShellLayout(),
);

/// The user's column choices, written back on every change.
final shellLayoutProvider = NotifierProvider<ShellLayoutNotifier, ShellLayout>(
  ShellLayoutNotifier.new,
);

class ShellLayoutNotifier extends Notifier<ShellLayout> {
  @override
  ShellLayout build() => ref.watch(initialShellLayoutProvider);

  void setSidebarNarrow(bool narrow) =>
      _set(state.copyWith(sidebarNarrow: narrow));

  void setPanelHidden(bool hidden) => _set(state.copyWith(panelHidden: hidden));

  void _set(ShellLayout next) {
    if (next == state) return;
    state = next;
    unawaited(ref.read(shellLayoutStoreProvider).write(next));
  }
}

/// The window behind the title bar; overridden in main with the real one.
final windowControlsProvider = Provider<WindowControls>(
  (ref) => InertWindowControls(),
);
