import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Windows app shares `mt_ui`, where a desktop window class now exists.
/// It is reachable only under `MTDesktopApp`, which a phone app must never
/// place; and a phone screen has no reason to ask for the desktop class.
void main() {
  test('**the guard**: the phone app takes no desktop branch', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          if (f.readAsStringSync() case final src
              when src.contains('MTDesktopApp') ||
                  src.contains('MTWindowClass.desktop'))
            f.path,
    ];
    expect(offenders, isEmpty);
  });
}
