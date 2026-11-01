import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Guard: every sheet and dialog goes through `showMTSheet` and
/// `showMTDialog`**, which give them the app's pace (a sheet 320 up and
/// 200 down, a dialog growing from 0.96). One raw call to Flutter's
/// function brings back its default motion on that screen alone.
void main() {
  test('no screen calls Flutter\'s sheet or dialog directly', () {
    final raw = RegExp(r'\bshow(Dialog|ModalBottomSheet)<');
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            raw.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
