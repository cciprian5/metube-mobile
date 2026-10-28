import 'dart:io';
import 'dart:typed_data';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory folder;
  late KeptCoverIndex kept;
  late ProbeFailureIndex failures;
  setUp(() {
    folder = Directory.systemTemp.createTempSync('covers');
    final store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    kept = KeptCoverIndex(store: store, mutex: mutex);
    failures = ProbeFailureIndex(store: store, mutex: mutex);
  });
  tearDown(() => folder.deleteSync(recursive: true));

  const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  const cover = 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg';
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);
  final frame = Uint8List.fromList([0xFF, 0xD8, 0xFF, 9, 9, 9]);

  CoverKeeper keeper(FetchedCover answer, {Uint8List? fromFile}) => CoverKeeper(
    kept: kept,
    failures: failures,
    folder: folder,
    fetch: (_) async => answer,
    fallback: (_) async => fromFile,
  );

  test('**the guard**: a cover the web still has is kept as a file, '
      'under the clip, and is no longer asked for', () async {
    final k = keeper(FetchedCover.found(jpeg));
    expect(await k.candidates({url: cover}), [url]);
    expect(await k.keep(url, cover), CoverOutcome.kept);
    final path = (await kept.artworkOf(url))!;
    expect(File(path).readAsBytesSync(), jpeg);
    expect(await k.candidates({url: cover}), isEmpty);
  });

  test('**the guard**: a cover gone at its source is replaced by a '
      'picture from the clip\'s own file', () async {
    final k = keeper(const FetchedCover.gone(), fromFile: frame);
    expect(await k.keep(url, cover), CoverOutcome.replaced);
    expect(File((await kept.artworkOf(url))!).readAsBytesSync(), frame);
  });

  test(
    'gone, with nothing from the file either: left alone for a day',
    () async {
      final k = keeper(const FetchedCover.gone());
      expect(await k.keep(url, cover), CoverOutcome.gone);
      expect(await kept.artworkOf(url), isNull);
      expect(await k.candidates({url: cover}), isEmpty);
    },
  );

  test('offline: nothing is noted, and it is asked again next time', () async {
    final k = keeper(const FetchedCover.failed(), fromFile: frame);
    expect(await k.keep(url, cover), CoverOutcome.failed);
    expect(await kept.artworkOf(url), isNull);
    expect(await k.candidates({url: cover}), [url]);
  });

  test('a clip with no online cover, or a path whose file is gone', () async {
    final k = keeper(FetchedCover.found(jpeg));
    await kept.put(url, '${folder.path}/missing.jpg');
    expect(await k.candidates({url: cover, 'other': null}), [url]);
    expect(await k.keep(url, cover), CoverOutcome.kept);
    expect(File((await kept.artworkOf(url))!).existsSync(), isTrue);
  });

  test('deleting the clip deletes the kept file', () async {
    final k = keeper(FetchedCover.found(jpeg));
    await k.keep(url, cover);
    final path = (await kept.artworkOf(url))!;
    await kept.removeKeysAndFiles([url]);
    expect(File(path).existsSync(), isFalse);
  });

  test(
    'a round keeps what it can, and rests when the network is gone',
    () async {
      var asked = 0;
      final k = CoverKeeper(
        kept: kept,
        failures: failures,
        folder: folder,
        fetch: (_) async {
          asked++;
          return const FetchedCover.failed();
        },
      );
      final covers = {for (var i = 0; i < 20; i++) 'u$i': cover};
      expect(await k.keepAll(covers, restAfter: 3), (kept: 0, replaced: 0));
      expect(asked, 3);
      final good = keeper(FetchedCover.found(jpeg));
      expect(await good.keepAll({url: cover, 'none': null}), (
        kept: 1,
        replaced: 0,
      ));
    },
  );
}
