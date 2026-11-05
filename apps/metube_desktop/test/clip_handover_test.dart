import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/clip_handover.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/local_copies.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/fake_api.dart';

void main() {
  late Directory root;
  late FakeApi api;
  late ClipHandover handover;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ember_handover_');
    api = FakeApi(ServerConfig(baseUrl: 'http://nas:8081'));
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWith((ref) => api),
        transferProvider.overrideWithValue(
          (api) => Transfer(api: api, retries: 1, backoff: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    handover = container.read(clipHandoverProvider);
  });
  tearDown(() => root.deleteSync(recursive: true));

  LibraryItem clip({String? localPath, bool onServer = true}) => LibraryItem(
    canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
    title: 'Night Drive',
    onServer: onServer,
    serverFilename: onServer ? 'Music/Night: Drive.mp4' : null,
    localPath: localPath,
  );

  test('**the guard**: a copy on this computer is handed over as it is, and '
      'nothing is pulled', () {
    final kept = File('${root.path}\\Night Drive.mp4')..writeAsBytesSync([1]);
    final item = clip(localPath: kept.path);
    expect(handover.localFile(item), kept.path);
    expect(handover.nameOf(item), 'Night Drive.mp4');
    expect(api.pulled, isEmpty);
  });

  test('a copy deleted in Explorer is not trusted: the server one is given, '
      'under a name Windows takes', () {
    final item = clip(localPath: '${root.path}\\gone.mp4');
    expect(handover.localFile(item), isNull);
    expect(handover.nameOf(item), 'Night_ Drive.mp4');
  });

  test('a clip neither here nor on the server has nothing to drag', () {
    expect(handover.nameOf(clip(onServer: false)), isNull);
  });

  test('**the guard**: a clip only on the server is pulled whole, and its '
      'folder goes once it has been handed over', () async {
    api.files['Music/Night: Drive.mp4'] = [1, 2, 3, 4];
    final progress = <double>[];
    final file = await handover.pull(clip(), onProgress: progress.add);
    expect(file.readAsBytesSync(), [1, 2, 3, 4]);
    expect(file.path, endsWith(r'\Night_ Drive.mp4'));
    expect(progress.last, 1);
    expect(api.deleted, isEmpty);
    await handover.discard(file);
    expect(file.parent.existsSync(), isFalse);
  });

  test('a pull that fails leaves no folder behind', () async {
    Set<String> drags() => {
      for (final d in Directory.systemTemp.listSync())
        if (d.path.contains('ember_drag_')) d.path,
    };
    final before = drags();
    await expectLater(handover.pull(clip()), throwsA(isA<MTApiException>()));
    expect(drags(), before);
  });
}
