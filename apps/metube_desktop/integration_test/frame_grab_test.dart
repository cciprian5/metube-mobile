import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:metube_desktop/platform/frame_grab.dart';

/// A frame through the **real** libmpv, which a widget test cannot load.
/// Run on Windows:
///
///     flutter test integration_test -d windows
///
/// The picture is a still image written here (the engine's trimmed build
/// reads no raw video), served by a local server that wants a password, so
/// the test needs no real one.
Uint8List _png() {
  const w = 64, h = 48;
  Uint8List chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    final b = ByteData(4)..setUint32(0, data.length);
    final crc = ByteData(4)..setUint32(0, _crc32(body));
    return Uint8List.fromList([
      ...b.buffer.asUint8List(),
      ...body,
      ...crc.buffer.asUint8List(),
    ]);
  }

  final header = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  final rows = <int>[
    for (var y = 0; y < h; y++) ...[
      0,
      for (var x = 0; x < w; x++) ...[200, 90, 40],
    ],
  ];
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ...chunk('IHDR', header.buffer.asUint8List()),
    ...chunk('IDAT', ZLibEncoder().convert(rows)),
    ...chunk('IEND', const []),
  ]);
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >>> 1) ^ 0xEDB88320 : crc >>> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

bool _isJpeg(Uint8List? b) =>
    b != null && b.length > 2 && b[0] == 0xFF && b[1] == 0xD8;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final image = _png();
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
          ..headers.contentType = ContentType('image', 'png')
          ..add(image);
      }
      await request.response.close();
    });
  });
  tearDownAll(() => server.close(force: true));
  setUp(asked.clear);

  testWidgets('a frame from the server, with its password', (tester) async {
    final picture = await tester.runAsync(
      () => grabFrame('http://127.0.0.1:${server.port}/download/a.png', {
        'Authorization': 'Basic b3duZXI6c2VjcmV0',
      }),
    );
    expect(_isJpeg(picture), isTrue);
    expect(asked, everyElement('Basic b3duZXI6c2VjcmV0'));
  });

  testWidgets('nothing, and no hang, when the server refuses', (tester) async {
    final picture = await tester.runAsync(
      () => grabFrame('http://127.0.0.1:${server.port}/download/a.png', {}),
    );
    expect(picture, isNull);
    expect(asked, isNotEmpty);
  });

  // A second of tone with a test pattern as its cover, a few kilobytes each.
  for (final name in ['cover.mp3', 'cover.opus']) {
    testWidgets('the cover embedded in $name', (tester) async {
      final file = File('integration_test/fixtures/$name').absolute;
      final picture = await tester.runAsync(() => grabFrame(file.path, {}));
      expect(_isJpeg(picture), isTrue);
    });
  }

  testWidgets('a frame from a copy on this computer', (tester) async {
    final dir = Directory.systemTemp.createTempSync('ember_frame_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}\\a.png')..writeAsBytesSync(image);
    final picture = await tester.runAsync(() => grabFrame(file.path, {}));
    expect(_isJpeg(picture), isTrue);
  });
}
