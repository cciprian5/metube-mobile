import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/covers/cover_shrink.dart';
import 'package:metube_desktop/data/covers/covers_data.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/features/clip/clip_actions.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:metube_desktop/features/library/artwork.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show cachedCoverFetcher;

import 'support/shell_harness.dart';

/// The web as YouTube answers it: a picture, or 404 for a video taken
/// down, or a server error.
class _Web extends FileService {
  _Web(this.answers);

  final Map<String, int> answers;
  final asked = <String>[];

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    asked.add(url);
    return _Answer(answers[url] ?? 500);
  }
}

class _Answer implements FileServiceResponse {
  _Answer(this.statusCode);

  @override
  final int statusCode;

  @override
  Stream<List<int>> get content => Stream.value([0xFF, 0xD8, 0xFF, 7]);

  @override
  int? get contentLength => 4;

  @override
  DateTime get validTill => DateTime.now().add(const Duration(hours: 1));

  @override
  String? get eTag => null;

  @override
  String get fileExtension => '.jpg';
}

void main() {
  const alive = 'https://i.ytimg.com/vi/aaaaaaaaaaa/hqdefault.jpg';
  const taken = 'https://i.ytimg.com/vi/bbbbbbbbbbb/hqdefault.jpg';
  const broken = 'https://i.ytimg.com/vi/ccccccccccc/hqdefault.jpg';
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('cache');
    // Registered first, so it runs last: after each cache is closed and
    // has written its list.
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  /// A cover cache over [web], closed at the end of the test.
  BaseCacheManager cacheOver(_Web web) {
    final cache = artworkCacheIn(dir.path, fileService: web);
    addTearDown(cache.dispose);
    return cache;
  }

  test('**the guard**: YouTube\'s 404 reads as a cover gone at its '
      'source, a server error as try again', () async {
    final web = _Web({alive: 200, taken: 404});
    final fetch = cachedCoverFetcher(cacheOver(web), (_) => const {});
    final found = await fetch(alive);
    expect(found.bytes, Uint8List.fromList([0xFF, 0xD8, 0xFF, 7]));
    final gone = await fetch(taken);
    expect((gone.bytes, gone.gone), (null, true));
    final failed = await fetch(broken);
    expect((failed.bytes, failed.gone), (null, false));
  });

  test('a picture the cache still holds is used without asking the web, '
      'however old: it may be the last copy left', () async {
    final web = _Web({alive: 200});
    final before = artworkCacheIn(dir.path, fileService: web);
    await before.downloadFile(alive);
    await before.dispose();
    // The app opened again, and YouTube has taken the video down since.
    web.answers[alive] = 404;
    web.asked.clear();
    final again = await cachedCoverFetcher(cacheOver(web), (_) => const {})(
      alive,
    );
    expect(again.bytes, isNotNull);
    expect(web.asked, isEmpty);
  });

  test('**the guard**: the library covers are kept as files, and a '
      'YouTube clip taken down gets a frame of its own file', () async {
    final covers = Directory('${dir.path}/kept');
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'http://127.0.0.1:9'),
    );
    addTearDown(api.close);
    LibraryItem clip(String id, String cover) => LibraryItem(
      canonicalUrl: 'https://www.youtube.com/watch?v=$id',
      title: id,
      onServer: true,
      serverFilename: '$id.mp4',
      thumbnail: cover,
      timestamp: DateTime(2026, 10, 20),
    );
    final frame = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 1]);
    final store = MemoryKeyValueStore();
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        coverFolderProvider.overrideWithValue(covers),
        apiClientProvider.overrideWith((ref) => api),
        artworkCacheProvider.overrideWithValue(
          cacheOver(_Web({alive: 200, taken: 404})),
        ),
        libraryItemsProvider.overrideWith(
          (ref) async => [
            clip('aaaaaaaaaaa', alive),
            clip('bbbbbbbbbbb', taken),
          ],
        ),
        frameGrabProvider.overrideWithValue((url, headers) async => frame),
      ],
    );
    addTearDown(container.dispose);
    container.read(coverEnrichmentProvider);
    final index = container.read(keptCoverIndexProvider);
    final clock = Stopwatch()..start();
    var kept = <String, String>{};
    while (kept.length < 2 && clock.elapsed < const Duration(seconds: 30)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      kept = await index.readAll();
    }
    expect(
      File(kept['https://www.youtube.com/watch?v=aaaaaaaaaaa']!)
          .readAsBytesSync(),
      [0xFF, 0xD8, 0xFF, 7],
    );
    expect(
      File(kept['https://www.youtube.com/watch?v=bbbbbbbbbbb']!)
          .readAsBytesSync(),
      frame,
    );
    // The round ends by looking over the kept covers; let it finish before
    // the folder goes.
    // Keeping the files reads the library again, and that second round
    // checks the folder once more.
    final done = [
      File('${covers.path}/.shrunk-640'),
      File('${covers.path}/.dark-checked'),
    ];
    while (!done.every((f) => f.existsSync()) &&
        clock.elapsed < const Duration(seconds: 40)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });

  test('**the guard**: a picture the decoder chokes on is kept as it came, '
      'and does not stop the round', () async {
    final cut = Uint8List.fromList([0xFF, 0xD8, 0xFF, 7]);
    expect(await shrinkCover(cut), cut);
  });

  testWidgets('**the guard**: deleting a clip deletes its kept cover', (
    tester,
  ) async {
    const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
    final h = ShellHarness(server: ServerConfig(baseUrl: 'http://nas:8081'));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmberSidebar)),
    );
    final file = File('${dir.path}/kept.jpg');
    await tester.runAsync(() async {
      file.writeAsBytesSync([0xFF, 0xD8, 0xFF, 7]);
      await container.read(keptCoverIndexProvider).put(url, file.path);
      await container.read(clipActionsProvider).deleteFromServer(url);
    });
    expect(file.existsSync(), isFalse);
    expect(await container.read(keptCoverIndexProvider).readAll(), isEmpty);
  });
}
