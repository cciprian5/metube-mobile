import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Windows app draws its own icon set (MTIcons); the borrowed shapes
/// come through it too. A stray Material glyph is the most visible sign of
/// an app assembled from defaults.
void main() {
  List<String> offenders(RegExp pattern) => [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File &&
          f.path.endsWith('.dart') &&
          pattern.hasMatch(f.readAsStringSync()))
        f.path,
  ];

  test('**the guard**: no Material Icons in lib', () {
    expect(offenders(RegExp(r'\bIcons\.')), isEmpty);
  });

  test('**the guard**: no Material progress indicators in lib', () {
    // The waiting and progress shapes are Wahaj's (MTSpinner, MTProgressBar,
    // MTFilmStrip) or drawn, like the mini window's hairline.
    expect(
      offenders(RegExp(r'\b(Linear|Circular)ProgressIndicator\(')),
      isEmpty,
    );
  });
}
