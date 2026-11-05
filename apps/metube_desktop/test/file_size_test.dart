import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A file that keeps growing is one that does too much: a screen stops at
/// 400 lines and any other file at 300, and past that it is split before
/// anything is added. A screen is a whole page, room, window or the
/// shell, which compose many parts by nature.
void main() {
  test('**the guard**: no file in lib outgrows its limit', () {
    final screen = RegExp(r'_(page|room|shell|window)\.dart$');
    final over = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync().length;
      final limit = screen.hasMatch(f.path) ? 400 : 300;
      if (lines > limit) over.add('${f.path}: $lines > $limit');
    }
    expect(over, isEmpty);
  });
}
