import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The phones draw the same Wahaj icon set (MTIcons) as the Windows app,
/// from one source: a stray Material glyph would be the one icon that does
/// not match its neighbours, and the most visible sign of an app assembled
/// from defaults.
void main() {
  test('**the guard**: no Material icon in lib', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(r'\bIcons\.|(?<![\w$])Icon\(|(?<![\w$])IconData\b')
                .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test("**the guard**: waiting is the Wahaj ring, never Material's spinner",
      () {
    // MTPullRefresh builds on RefreshIndicator.noSpinner, which the pattern
    // leaves alone; the plain one draws Material's floating disc.
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(
              r'CircularProgressIndicator|(?<![\w$.])RefreshIndicator\(',
            ).hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
