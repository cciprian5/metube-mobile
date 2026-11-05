import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/platform/media_kit_debug.dart';
import 'package:win32/win32.dart';

void main() {
  test('**the guard**: a fresh debug process drops the address note a dead '
      'process left under its number, and marks itself started', () {
    final note = File(
      '${Directory.systemTemp.path}\\'
      'com.alexmercerind.media_kit.NativeReferenceHolder.$pid',
    )..writeAsStringSync('2341253812320');
    addTearDown(() {
      if (note.existsSync()) note.deleteSync();
    });

    forgetStaleMediaKitNote();

    expect(note.existsSync(), isFalse);
    final name = TEXT('EMBER_MEDIA_KIT_STARTED');
    final buffer = wsalloc(8);
    try {
      // The value is "1": one character.
      expect(GetEnvironmentVariable(name, buffer, 8), 1);
    } finally {
      free(name);
      free(buffer);
    }
  }, testOn: 'windows');
}
