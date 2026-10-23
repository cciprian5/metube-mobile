import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Windows app draws its own icon set (MTIcons); the borrowed shapes
/// come through it too. A stray Material glyph is the most visible sign of
/// an app assembled from defaults.
void main() {
  test('**the guard**: no Material Icons in lib', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(r'\bIcons\.').hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
