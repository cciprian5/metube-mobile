import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The sizes in an .ico file, from its directory: a count, then one entry
/// of 16 bytes per image whose first byte is the width (0 meaning 256).
List<int> icoSizes(String path) {
  final bytes = ByteData.sublistView(File(path).readAsBytesSync());
  final count = bytes.getUint16(4, Endian.little);
  return [
    for (var i = 0; i < count; i++)
      switch (bytes.getUint8(6 + i * 16)) {
        0 => 256,
        final w => w,
      },
  ]..sort();
}

void main() {
  test('**the guard**: the app icon carries every size Windows asks for, '
      'so the taskbar never stretches a small one', () {
    expect(icoSizes('windows/runner/resources/app_icon.ico'), [
      16,
      20,
      24,
      32,
      40,
      48,
      64,
      256,
    ]);
  });

  test('the tray icons carry the sizes of 100 to 300 percent scaling', () {
    for (final theme in ['light', 'dark']) {
      expect(icoSizes('assets/tray/tray_$theme.ico'), [16, 20, 24, 32, 40, 48]);
    }
  });
}
