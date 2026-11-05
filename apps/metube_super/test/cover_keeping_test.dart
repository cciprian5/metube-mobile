import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/cover_keeping.dart';
import 'package:metube_super/features/library/library_actions.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

/// YouTube deletes a video's picture with the video, so a clip taken down
/// at its source used to lose its card's face though its file was safe on
/// the server.
void main() {
  const alive = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
  const taken = 'https://www.youtube.com/watch?v=bbbbbbbbbbb';
  const aliveCover = 'https://i.ytimg.com/vi/aaaaaaaaaaa/hqdefault.jpg';
  const takenCover = 'https://i.ytimg.com/vi/bbbbbbbbbbb/hqdefault.jpg';
  final official = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]);
  final frame = Uint8List.fromList([0xFF, 0xD8, 0xFF, 2]);

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('mtf_covers'));
  tearDown(() => temp.deleteSync(recursive: true));

  ProviderContainer container() {
    LibraryItem clip(String url, String cover) => LibraryItem(
      canonicalUrl: url,
      title: url,
      onServer: true,
      thumbnail: cover,
    );
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
        ),
        keptCoverFolderProvider.overrideWith(
          (ref) async => Directory('${temp.path}/kept'),
        ),
        coverFetcherProvider.overrideWithValue(
          (url) async => url == aliveCover
              ? FetchedCover.found(official)
              : const FetchedCover.gone(),
        ),
        libraryItemsProvider.overrideWith(
          (ref) async => [clip(alive, aliveCover), clip(taken, takenCover)],
        ),
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
      'gone at YouTube is replaced by the frame the phone took', () async {
    final c = container();
    // The enricher's frame of the clip taken down, as it keeps them.
    final framePath = '${temp.path}/frame.jpg';
    File(framePath).writeAsBytesSync(frame);
    await c.read(artworkIndexProvider).put(taken, framePath);

    c.read(coverKeepingProvider);
    final kept = await keptOnce(c, 2);
    expect(File(kept[alive]!).readAsBytesSync(), official);
    expect(File(kept[taken]!).readAsBytesSync(), frame);
  });

  test('**the guard**: deleting the clip deletes its kept cover', () async {
    final c = container();
    c.read(coverKeepingProvider);
    final kept = await keptOnce(c, 1);
    final file = File(kept[alive]!);
    expect(file.existsSync(), isTrue);
    await c.read(libraryActionsProvider).pruneItemData([alive]);
    expect(file.existsSync(), isFalse);
    expect((await c.read(keptCoverIndexProvider).readAll())[alive], isNull);
  });
}
