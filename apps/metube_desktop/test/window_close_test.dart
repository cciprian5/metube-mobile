import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('**the guard**: the window is never closed with destroy()', () {
    // Measured on Windows: destroy() ends the message loop before the
    // window is destroyed, and the app then took 17 seconds to exit.
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('windowManager.destroy('))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
