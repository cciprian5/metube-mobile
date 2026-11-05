import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:metube_desktop/platform/file_clipboard_windows.dart';
import 'package:metube_desktop/platform/shape_probe.dart';

/// The library's new Windows tools through the **real** libmpv and the
/// real clipboard, which a widget test cannot reach. Run on Windows:
///
///     flutter test integration_test/file_tools_test.dart -d windows
///
/// The clips are fixtures here (a 2.5 s portrait H.264 video, a one-second
/// song with a cover), served by a local server that wants a password, so
/// the test needs no real one. The clipboard's text is put back after.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final video = File('integration_test/fixtures/portrait.mp4').absolute;
  final song = File('integration_test/fixtures/cover.mp3').absolute;
  late HttpServer server;
  final asked = <String?>[];

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      asked.add(auth);
      if (auth != 'Basic b3duZXI6c2VjcmV0') {
        request.response.statusCode = HttpStatus.unauthorized;
      } else {
        request.response
          ..headers.contentType = ContentType('video', 'mp4')
          ..add(video.readAsBytesSync());
      }
      await request.response.close();
    });
  });
  tearDownAll(() => server.close(force: true));
  setUp(asked.clear);

  group("a clip's length and shape", () {
    testWidgets('a portrait video on this computer', (tester) async {
      final shape = await tester.runAsync(() => probeShape(video.path, {}));
      expect(shape!.duration.inMilliseconds, closeTo(2500, 100));
      expect(shape.aspectRatio, closeTo(144 / 256, 0.01));
    });

    testWidgets('from the server, with its password', (tester) async {
      final shape = await tester.runAsync(
        () => probeShape('http://127.0.0.1:${server.port}/download/a.mp4', {
          'Authorization': 'Basic b3duZXI6c2VjcmV0',
        }),
      );
      expect(shape!.duration.inMilliseconds, closeTo(2500, 100));
      expect(asked, everyElement('Basic b3duZXI6c2VjcmV0'));
    });

    testWidgets('nothing, and no hang, when the server refuses', (
      tester,
    ) async {
      final shape = await tester.runAsync(
        () => probeShape('http://127.0.0.1:${server.port}/download/a.mp4', {}),
      );
      expect(shape, isNull);
      expect(asked, isNotEmpty);
    });

    testWidgets('**the guard**: a song keeps its length, and its cover is '
        'not taken for its shape', (tester) async {
      final shape = await tester.runAsync(() => probeShape(song.path, {}));
      expect(shape!.duration.inMilliseconds, closeTo(1000, 150));
      expect(shape.aspectRatio, isNull);
    });
  });

  group('the clipboard', () {
    testWidgets('**the guard**: a file goes on it as a file, as Explorer '
        'copies it, and Windows reads its path back', (tester) async {
      final before = await Clipboard.getData(Clipboard.kTextPlain);
      addTearDown(() async {
        await Clipboard.setData(ClipboardData(text: before?.text ?? ''));
      });
      final dir = Directory.systemTemp.createTempSync('ember_clip_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}\\Night Drive (1080p).mp4')
        ..writeAsBytesSync(video.readAsBytesSync());

      expect(putFilesOnClipboard([file.path]), isTrue);
      final read = await tester.runAsync(
        () => Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '[Console]::OutputEncoding=[Text.Encoding]::UTF8;'
              r'(Get-Clipboard -Format FileDropList) | % { $_.FullName }',
        ]),
      );
      expect((read!.stdout as String).trim(), file.path);
    });

    testWidgets('the room on a drive is read', (tester) async {
      final free = freeBytesAt(Directory.systemTemp.path);
      expect(free, isNotNull);
      expect(free, greaterThan(0));
    });
  });
}
