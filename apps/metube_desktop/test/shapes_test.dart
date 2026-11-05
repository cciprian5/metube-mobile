import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/shapes/shapes_data.dart';
import 'package:metube_desktop/di.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show MediaShape;

import 'support/fake_api.dart';

LibraryItem _clip(
  String id, {
  Duration? duration,
  String? localPath,
  bool onServer = true,
}) => LibraryItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: id,
  onServer: onServer,
  serverFilename: onServer ? '$id.mp4' : null,
  localPath: localPath,
  duration: duration,
  timestamp: DateTime(2026, 11, 1),
);

/// **Every clip's length in Ember** (owner's request 2026-11-04): the server
/// sends none, so a clip never played on this computer showed no length.
/// Its header is read in the background, as the phone's enricher does.
void main() {
  group('which clips are read, and where', () {
    test('only those with no length yet and a file to read', () {
      final items = [
        _clip('known', duration: const Duration(minutes: 3)),
        _clip('unknown'),
        _clip('nowhere', onServer: false),
        _clip('tried'),
      ];
      expect(
        [
          for (final i in shapeCandidates(items, {'https://youtu.be/tried'}))
            i.title,
        ],
        ['unknown'],
      );
    });

    test("**the guard**: a copy here is read in place with no credentials; "
        "only the server's own file gets the server's headers", () {
      final root = Directory.systemTemp.createTempSync('ember_shape_');
      addTearDown(() => root.deleteSync(recursive: true));
      final file = File('${root.path}\\kept.mp4')..writeAsBytesSync([1]);
      final api = MeTubeApiClient(
        config: ServerConfig(
          baseUrl: 'http://nas:8081',
          username: 'me',
          password: 'secret',
        ),
      );
      addTearDown(api.close);

      final local = shapeSourceOf(_clip('a', localPath: file.path), api)!;
      expect(local.url, file.path);
      expect(local.headers, isEmpty);

      final remote = shapeSourceOf(_clip('b'), api)!;
      expect(remote.url, startsWith('http://nas:8081/'));
      expect(remote.headers, api.streamingHeaders);
      expect(remote.headers, isNotEmpty);
    });
  });

  group('learning in the background', () {
    late MemoryKeyValueStore store;
    setUp(() => store = MemoryKeyValueStore());

    ProviderContainer make(List<LibraryItem> items, ShapeProbe probe) {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWith(
            (ref) => FakeApi(ServerConfig(baseUrl: 'http://nas:8081')),
          ),
          libraryItemsProvider.overrideWith((ref) async => items),
          shapeProbeProvider.overrideWithValue(probe),
          shapeProbeGapProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<Map<String, MediaShape>> learned(ProviderContainer c) async {
      c.read(shapeEnrichmentProvider);
      await c.read(libraryItemsProvider.future);
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return c.read(mediaShapeIndexProvider).readAll();
    }

    test('**the guard**: a clip never played gets its length and shape, and '
        'is kept so it is read once', () async {
      final asked = <String>[];
      final c = make([_clip('a'), _clip('b')], (url, headers) async {
        asked.add(url);
        return const ProbedShape(
          duration: Duration(minutes: 4, seconds: 2),
          aspectRatio: 16 / 9,
        );
      });
      final shapes = await learned(c);
      expect(shapes['https://youtu.be/a']!.duration.inSeconds, 242);
      expect(shapes['https://youtu.be/b']!.aspectRatio, closeTo(16 / 9, 1e-9));
      expect(asked, hasLength(2));
    });

    test('sound alone is kept with a square shape, as on the phone', () async {
      final c = make(
        [_clip('song')],
        (url, headers) async =>
            const ProbedShape(duration: Duration(minutes: 3)),
      );
      final shapes = await learned(c);
      expect(shapes['https://youtu.be/song']!.aspectRatio, 1);
    });

    test('**the guard**: a server that stops answering is left after six '
        'misses, and those are asked again later', () async {
      var asked = 0;
      final c = make([for (var i = 0; i < 10; i++) _clip('c$i')], (
        url,
        headers,
      ) async {
        asked++;
        return null;
      });
      expect(await learned(c), isEmpty);
      expect(asked, 6);

      c.invalidate(libraryItemsProvider);
      await learned(c);
      expect(asked, 12);
    });

    test('with no engine (a test or a failed start) nothing is read', () async {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          libraryItemsProvider.overrideWith((ref) async => [_clip('a')]),
        ],
      );
      addTearDown(c.dispose);
      c.read(shapeEnrichmentProvider);
      await c.read(libraryItemsProvider.future);
      expect(await c.read(mediaShapeIndexProvider).readAll(), isEmpty);
    });
  });
}
