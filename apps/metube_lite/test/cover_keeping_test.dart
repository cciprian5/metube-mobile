import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/cover_keeping.dart';
import 'package:metube_lite/features/downloads_library/library_actions.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// YouTube deletes a video's picture with the video, so a clip taken down
/// at its source lost its card's face though the file was on the phone.
void main() {
  // Deleting rescans the gallery through a platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();
  const alive = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
  const taken = 'https://www.youtube.com/watch?v=bbbbbbbbbbb';
  const aliveCover = 'https://i.ytimg.com/vi/aaaaaaaaaaa/hqdefault.jpg';
  const takenCover = 'https://i.ytimg.com/vi/bbbbbbbbbbb/hqdefault.jpg';
  final official = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]);
  final frame = Uint8List.fromList([0xFF, 0xD8, 0xFF, 2]);

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('mtf_lite_covers'));
  tearDown(() => temp.deleteSync(recursive: true));

  LocalItem clip(String url, String cover) {
    final file = File('${temp.path}/${url.substring(url.length - 3)}.mp4')
      ..writeAsBytesSync(const [0]);
    return LocalItem(
      key: url,
      path: file.path,
      canonicalUrl: url,
      title: url,
      sizeBytes: 1,
      modified: DateTime(2026, 10, 20),
      thumbnail: cover,
    );
  }

  ProviderContainer container(List<LocalItem> items) {
    final framed = <String>[];
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const LiteSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_lite.log'),
        ),
        keptCoverFolderProvider.overrideWith(
          (ref) async => Directory('${temp.path}/kept'),
        ),
        coverFetcherProvider.overrideWithValue(
          (url) async => url == aliveCover
              ? FetchedCover.found(official)
              : const FetchedCover.gone(),
        ),
        localFrameProvider.overrideWithValue((path) async {
          framed.add(path);
          return frame;
        }),
        localMediaProvider.overrideWith((ref) async => items),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<Map<String, String>> keptOnce(ProviderContainer c, int count) async {
    final index = c.read(keptCoverIndexProvider);
    final clock = Stopwatch()..start();
    var kept = <String, String>{};
    while (kept.length < count && clock.elapsed < const Duration(seconds: 20)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      kept = await index.readAll();
    }
    return kept;
  }

  test('**the guard**: the official cover is kept on the phone, and one '
      'gone at YouTube is replaced by a frame of the file', () async {
    final c = container([clip(alive, aliveCover), clip(taken, takenCover)]);
    c.read(coverKeepingProvider);
    final kept = await keptOnce(c, 2);
    expect(File(kept[alive]!).readAsBytesSync(), official);
    expect(File(kept[taken]!).readAsBytesSync(), frame);
  });

  test('**the guard**: deleting the file deletes its kept cover', () async {
    final item = clip(alive, aliveCover);
    final c = container([item]);
    c.read(coverKeepingProvider);
    final kept = await keptOnce(c, 1);
    final file = File(kept[alive]!);
    expect(file.existsSync(), isTrue);
    await c.read(libraryActionsProvider).deleteFiles([item]);
    expect(file.existsSync(), isFalse);
    expect((await c.read(keptCoverIndexProvider).readAll())[alive], isNull);
  });

  test('**the guard**: a kept cover is the face of its file, before the '
      'online address the index holds', () {
    expect(
      LocalItem.coverOf(
        alive,
        '/x.mp4',
        kept: {alive: '/kept/a.jpg'},
        artwork: {alive: aliveCover},
      ),
      '/kept/a.jpg',
    );
    expect(
      LocalItem.coverOf(
        alive,
        '/x.mp4',
        kept: const {},
        artwork: const {'/x.mp4': '/thumbs/x.jpg'},
      ),
      '/thumbs/x.jpg',
    );
  });
}
