import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every corner in the Windows app comes from the desktop corner scale
/// (MTCorners.desktop). A number typed in place is how one card ends up
/// rounder than its neighbour.
void main() {
  test('**the guard**: no corner radius written as a number', () {
    final literal = RegExp(r'(Border)?Radius\.circular\(\s*\d');
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            literal.hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
