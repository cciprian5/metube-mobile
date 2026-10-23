import 'dart:convert';

import 'package:mt_core/mt_core.dart';

/// Which columns the user folded away, kept per computer like the window
/// itself: a wide monitor and a laptop want different answers.
class ShellLayout {
  const ShellLayout({this.sidebarNarrow = false, this.panelHidden = false});

  /// The sidebar shows icons alone (72 wide instead of 240).
  final bool sidebarNarrow;

  /// The right panel (transcript, up next, details) is folded away.
  final bool panelHidden;

  ShellLayout copyWith({bool? sidebarNarrow, bool? panelHidden}) =>
      ShellLayout(
        sidebarNarrow: sidebarNarrow ?? this.sidebarNarrow,
        panelHidden: panelHidden ?? this.panelHidden,
      );

  @override
  bool operator ==(Object other) =>
      other is ShellLayout &&
      other.sidebarNarrow == sidebarNarrow &&
      other.panelHidden == panelHidden;

  @override
  int get hashCode => Object.hash(sidebarNarrow, panelHidden);
}

/// Reads and writes [ShellLayout] through the one storage lock.
class ShellLayoutStore {
  ShellLayoutStore({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const key = 'ember_shell_layout';

  /// Unknown or damaged entries read as the default layout.
  Future<ShellLayout> read() async {
    final raw = await store.getString(key);
    if (raw == null) return const ShellLayout();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const ShellLayout();
      return ShellLayout(
        sidebarNarrow: json['sidebarNarrow'] == true,
        panelHidden: json['panelHidden'] == true,
      );
    } on FormatException {
      return const ShellLayout();
    }
  }

  Future<void> write(ShellLayout layout) => mutex.run(
    () => store.setString(
      key,
      jsonEncode({
        'sidebarNarrow': layout.sidebarNarrow,
        'panelHidden': layout.panelHidden,
      }),
    ),
  );
}
