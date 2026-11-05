import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/platform/media_kit_port.dart';

/// media_kit breaks drag and drop after a few disposed players, so the app
/// keeps one engine for its whole life.
void main() {
  setUp(OnePlayerGuard.resetForTest);

  test('**the guard**: a second player is refused', () {
    OnePlayerGuard.claim();
    expect(OnePlayerGuard.claim, throwsStateError);
  });

  List<String> filesMatching(RegExp pattern) => [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File &&
          f.path.endsWith('.dart') &&
          pattern.hasMatch(f.readAsStringSync()))
        f.path.replaceAll(r'\', '/'),
  ];

  test('**the guard**: the engine is built in one place only', () {
    expect(filesMatching(RegExp(r'\bPlayer\(')), [
      'lib/platform/media_kit_port.dart',
    ]);
  });

  test('**the guard**: nothing ever disposes the engine', () {
    expect(filesMatching(RegExp(r'\b_?player\.dispose\(')), isEmpty);
  });

  test("mpv's extended-length path names the file that was opened", () {
    // Measured on Windows: media_kit opens the forward-slash form and mpv
    // reports the \\?\ form; a plain comparison timed out every local file.
    expect(
      MediaKitPort.samePath(r'\\?\C:\Clips\a.wav', 'C:/Clips/a.wav'),
      isTrue,
    );
    expect(
      MediaKitPort.samePath(r'C:\Clips\a.wav', r'C:\Clips\b.wav'),
      isFalse,
    );
    expect(
      MediaKitPort.samePath(
        'https://srv/download/My%20Clip.mp4',
        'https://srv/download/My Clip.mp4',
      ),
      isTrue,
    );
  });
}
