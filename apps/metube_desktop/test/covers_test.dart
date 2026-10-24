import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/di.dart';
import 'package:image/image.dart' as img;
import 'package:metube_desktop/data/covers/cover_enricher.dart';
import 'package:metube_desktop/data/covers/cover_shrink.dart';
import 'package:metube_desktop/data/covers/covers_data.dart';
import 'package:metube_desktop/data/covers/mp4_cover.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

/// An MP4 box: a 32-bit size, a four-letter type, the body.
Uint8List _box(String type, List<int> body) {
  final b = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, body.length + 8)).buffer.asUint8List())
    ..add(ascii.encode(type))
    ..add(body);
  return b.toBytes();
}

final _jpeg = Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  1,
  2,
  3,
  4,
  0xFF,
  0xD9,
]);

/// The iTunes layout yt-dlp writes: moov > udta > meta(full) > ilst > covr.
Uint8List _moov({Uint8List? cover}) => _box('moov', [
  ..._box('mvhd', List.filled(20, 0)),
  ..._box('udta', [
    ..._box('meta', [
      0, 0, 0, 0, // version and flags
      ..._box('hdlr', List.filled(12, 0)),
      ..._box('ilst', [
        if (cover != null)
          ..._box('covr', [
            ..._box('data', [0, 0, 0, 13, 0, 0, 0, 0, ...cover]),
          ]),
      ]),
    ]),
  ]),
]);

Uint8List _file({required bool moovFirst, Uint8List? cover, int media = 4096}) {
  final ftyp = _box('ftyp', ascii.encode('M4A mp42isom'));
  final mdat = _box('mdat', List.filled(media, 7));
  final moov = _moov(cover: cover);
  return Uint8List.fromList(
    moovFirst ? [...ftyp, ...moov, ...mdat] : [...ftyp, ...mdat, ...moov],
  );
}

/// Reads ranges of [bytes] and counts how much was asked for.
class _Ranges {
  _Ranges(this.bytes);
  final Uint8List bytes;
  int read = 0;

  Future<Uint8List> call(int start, int length) async {
    if (start >= bytes.length) return Uint8List(0);
    final end = (start + length).clamp(0, bytes.length);
    read += end - start;
    return Uint8List.sublistView(bytes, start, end);
  }
}

void main() {
  group('the cover inside an MP4 or M4A', () {
    test('found at the start of a streaming file', () async {
      final r = _Ranges(_file(moovFirst: true, cover: _jpeg));
      expect(await Mp4Cover.find(r.call), _jpeg);
    });

    test('found after the media, without reading the media', () async {
      // Two megabytes of media before the moov box.
      final r = _Ranges(
        _file(moovFirst: false, cover: _jpeg, media: 2 * 1024 * 1024),
      );
      expect(await Mp4Cover.find(r.call), _jpeg);
      expect(r.read, lessThan(Mp4Cover.firstRead + 4096));
    });

    test('a file with none, or a damaged one, gives nothing', () async {
      expect(await Mp4Cover.find(_Ranges(_file(moovFirst: true)).call), isNull);
      final broken = _file(moovFirst: true, cover: _jpeg)..[3] = 3; // size 3
      expect(await Mp4Cover.find(_Ranges(broken).call), isNull);
      expect(await Mp4Cover.find(_Ranges(Uint8List(0)).call), isNull);
    });
  });

  group('looking for missing covers', () {
    late Directory dir;
    late MemoryKeyValueStore store;
    late ArtworkIndex artwork;
    late ProbeFailureIndex failures;
    final now = DateTime(2026, 10, 24, 12);

    setUp(() {
      dir = Directory.systemTemp.createTempSync('ember_covers_');
      store = MemoryKeyValueStore();
      artwork = ArtworkIndex(store: store, mutex: PrefsMutex());
      failures = ProbeFailureIndex(store: store, mutex: PrefsMutex());
    });
    tearDown(() => dir.deleteSync(recursive: true));

    LibraryItem clip(String id, {bool audio = true, String? thumbnail}) =>
        LibraryItem(
          canonicalUrl: 'https://soundcloud.com/a/$id',
          title: id,
          onServer: true,
          isAudio: audio,
          thumbnail: thumbnail,
          serverFilename: '/audio_download/$id.m4a',
        );

    CoverEnricher enricher(
      Map<String, Uint8List> files, {
      DateTime? at,
      FrameFor? frames,
    }) => CoverEnricher(
      artwork: artwork,
      failures: failures,
      folder: Directory('${dir.path}/embedded'),
      now: () => at ?? now,
      frameFor: frames,
      readerFor: (item) => switch (files[item.title]) {
        final bytes? => _Ranges(bytes).call,
        null => null,
      },
    );

    test('only audio with no cover yet is asked about', () async {
      await artwork.put(clip('known').canonicalUrl, 'C:/x.jpg');
      final file = _file(moovFirst: true, cover: _jpeg);
      final e = enricher({'new': file, 'known': file, 'youtube': file});
      final asked = await e.candidates([
        clip('new'),
        clip('known'),
        clip('video', audio: false),
        clip('youtube', thumbnail: 'https://i.ytimg.com/vi/x/hqdefault.jpg'),
      ]);
      expect(asked.map((i) => i.title), ['new']);
    });

    test('a found cover is kept on disk and in the index', () async {
      final e = enricher({'a': _file(moovFirst: true, cover: _jpeg)});
      expect(await e.enrich(clip('a')), isTrue);
      final path = await artwork.artworkOf(clip('a').canonicalUrl);
      expect(path, endsWith('.jpg'));
      expect(File(path!).readAsBytesSync(), _jpeg);
    });

    test(
      '**the guard**: a cover already known is never written over',
      () async {
        // Found by now from elsewhere (YouTube's, or another pass).
        final e = enricher({'a': _file(moovFirst: true, cover: _jpeg)});
        await artwork.put(
          clip('a').canonicalUrl,
          'https://i.ytimg.com/vi/a.jpg',
        );
        expect(await e.enrich(clip('a')), isFalse);
        expect(
          await artwork.artworkOf(clip('a').canonicalUrl),
          'https://i.ytimg.com/vi/a.jpg',
        );
      },
    );

    test('a clip with none is left alone for a day', () async {
      final e = enricher({'a': _file(moovFirst: true)});
      expect(await e.enrich(clip('a')), isFalse);
      expect(await e.candidates([clip('a')]), isEmpty);
      final tomorrow = enricher({
        'a': _file(moovFirst: true),
      }, at: now.add(const Duration(days: 2)));
      expect(await tomorrow.candidates([clip('a')]), hasLength(1));
    });

    test('audio the server cannot be asked about is not a candidate, so it '
        'never counts as a miss', () async {
      expect(await enricher({}).candidates([clip('local')]), isEmpty);
    });

    group('a video with no cover', () {
      final asked = <String>[];
      setUp(asked.clear);
      FrameFor frames(Uint8List? picture) => (item) async {
        asked.add(item.title);
        return picture;
      };

      test('is asked about only when frames can be taken', () async {
        final video = clip('reel', audio: false);
        expect(await enricher({}).candidates([video]), isEmpty);
        final e = enricher({}, frames: frames(_jpeg));
        expect((await e.candidates([video])).map((i) => i.title), ['reel']);
      });

      test('keeps its frame on disk and in the index', () async {
        final e = enricher({}, frames: frames(_jpeg));
        expect(await e.enrich(clip('reel', audio: false)), isTrue);
        final path = await artwork.artworkOf(clip('reel').canonicalUrl);
        expect(File(path!).readAsBytesSync(), _jpeg);
        expect(asked, ['reel']);
      });

      test(
        "**the guard**: YouTube's cover is never replaced by a frame",
        () async {
          final e = enricher({}, frames: frames(_jpeg));
          final youtube = clip(
            'yt',
            audio: false,
            thumbnail: 'https://i.ytimg.com/vi/x/hqdefault.jpg',
          );
          expect(await e.candidates([youtube]), isEmpty);
        },
      );

      test('**the guard**: an MP3, Opus or FLAC cover comes from the engine, '
          'without reading ranges meant for MP4', () async {
        var ranges = 0;
        final e = CoverEnricher(
          artwork: artwork,
          failures: failures,
          folder: Directory('${dir.path}/embedded'),
          now: () => now,
          frameFor: frames(_jpeg),
          readerFor: (_) => (start, length) async {
            ranges++;
            return Uint8List(0);
          },
        );
        for (final name in ['a.mp3', 'b.opus', 'c.flac']) {
          final song = LibraryItem(
            canonicalUrl: 'https://soundcloud.com/a/$name',
            title: name,
            onServer: true,
            isAudio: true,
            serverFilename: '/audio_download/$name',
          );
          expect(await e.candidates([song]), hasLength(1));
          expect(await e.enrich(song), isTrue);
        }
        expect(ranges, 0);
        expect(asked, ['a.mp3', 'b.opus', 'c.flac']);
      });

      test('an M4A with no cover inside is asked of the engine too', () async {
        final e = enricher({
          'a': _file(moovFirst: true),
        }, frames: frames(_jpeg));
        expect(await e.enrich(clip('a')), isTrue);
        expect(asked, ['a']);
      });

      test('one that gives no frame is left alone for a day', () async {
        final e = enricher({}, frames: frames(null));
        final video = clip('broken', audio: false);
        expect(await e.enrich(video), isFalse);
        expect(await e.candidates([video]), isEmpty);
      });
    });
  });

  group("**the guard**: where a video's frame is read from", () {
    final api = MeTubeApiClient(
      config: ServerConfig(
        baseUrl: 'http://127.0.0.1:9',
        username: 'owner',
        password: 'secret',
      ),
    );
    tearDownAll(api.close);
    final calls = <(String, Map<String, String>)>[];
    setUp(calls.clear);
    Future<Uint8List?> grab(String url, Map<String, String> headers) async {
      calls.add((url, headers));
      return _jpeg;
    }

    test("the server's file, with the server's own password", () async {
      await videoFrameFor(grab, api)(
        const LibraryItem(
          canonicalUrl: 'https://www.instagram.com/reel/a/',
          title: 'a',
          onServer: true,
          serverFilename: 'Kids/a.mp4',
        ),
      );
      final (url, headers) = calls.single;
      expect(url, startsWith('http://127.0.0.1:9/'));
      expect(url, endsWith('a.mp4'));
      expect(headers['Authorization'], startsWith('Basic '));
    });

    test('a copy on this computer, read in place with no password', () async {
      final dir = Directory.systemTemp.createTempSync('ember_local_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.mp4')..writeAsBytesSync([0]);
      await videoFrameFor(grab, api)(
        LibraryItem(
          canonicalUrl: 'https://www.instagram.com/reel/a/',
          title: 'a',
          onServer: true,
          serverFilename: 'a.mp4',
          localPath: file.path,
        ),
      );
      expect(calls.single, (file.path, const <String, String>{}));
    });

    test('nothing for a clip neither here nor there', () async {
      final picture = await videoFrameFor(grab, api)(
        const LibraryItem(canonicalUrl: 'https://x.com/a', title: 'a'),
      );
      expect(picture, isNull);
      expect(calls, isEmpty);
    });
  });

  test('**the guard**: the server reader sends the password to the server '
      'and reads only a range', () async {
    final file = _file(moovFirst: true, cover: _jpeg, media: 600 * 1024);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = <String?>[];
    final ranges = <String?>[];
    server.listen((request) async {
      seen.add(request.headers.value(HttpHeaders.authorizationHeader));
      final range = request.headers.value(HttpHeaders.rangeHeader);
      ranges.add(range);
      final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range ?? '');
      final start = int.parse(m!.group(1)!);
      final end = (int.parse(m.group(2)!) + 1).clamp(0, file.length);
      request.response
        ..statusCode = HttpStatus.partialContent
        ..add(file.sublist(start, end));
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final api = MeTubeApiClient(
      config: ServerConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        username: 'owner',
        password: 'secret',
      ),
    );
    addTearDown(api.close);

    final cover = await Mp4Cover.find(serverRangeReader(api, 'clip.m4a'));
    expect(cover, _jpeg);
    expect(seen, everyElement(startsWith('Basic ')));
    expect(ranges.first, 'bytes=0-${Mp4Cover.firstRead - 1}');
  });

  test('**the guard**: the newest clips get their frames first, as the '
      'library opens, not the oldest', () async {
    final dir = Directory.systemTemp.createTempSync('ember_order_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'http://127.0.0.1:9'),
    );
    addTearDown(api.close);
    LibraryItem video(String id, int day) => LibraryItem(
      canonicalUrl: 'https://www.instagram.com/reel/$id/',
      title: id,
      onServer: true,
      serverFilename: '$id.mp4',
      timestamp: DateTime(2026, 10, day),
    );
    final asked = <String>[];
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        coverFolderProvider.overrideWithValue(dir),
        apiClientProvider.overrideWith((ref) => api),
        libraryItemsProvider.overrideWith(
          (ref) async => [video('old', 1), video('new', 20), video('mid', 9)],
        ),
        frameGrabProvider.overrideWithValue((url, headers) async {
          asked.add(url.split('/').last);
          return _jpeg;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(coverEnrichmentProvider);
    final clock = Stopwatch()..start();
    while (asked.length < 3 && clock.elapsed < const Duration(seconds: 30)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(asked, ['new.mp4', 'mid.mp4', 'old.mp4']);
    // The round ends by looking over the kept covers; let it finish before
    // the folder goes.
    final done = File('${dir.path}/.shrunk-$coverWidth');
    while (!done.existsSync() && clock.elapsed < const Duration(seconds: 40)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });

  group('**the guard**: covers are kept card-sized', () {
    // A phone video's frame, as the engine writes it.
    Uint8List frame(int w, int h) =>
        img.encodeJpg(img.Image(width: w, height: h), quality: 60);
    int widthOf(Uint8List bytes) => img.decodeImage(bytes)!.width;

    test('a large frame is made no wider than a card', () async {
      final small = await shrinkCover(frame(1080, 1920));
      expect(widthOf(small), coverWidth);
      expect(img.decodeImage(small)!.height, inInclusiveRange(1137, 1138));
    });

    test('a small one, or one that cannot be read, is left alone', () async {
      final small = frame(320, 180);
      expect(await shrinkCover(small), same(small));
      expect(await shrinkCover(_jpeg), same(_jpeg));
    });

    test('the enricher keeps the small one', () async {
      final dir = Directory.systemTemp.createTempSync('ember_shrink_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = MemoryKeyValueStore();
      final artwork = ArtworkIndex(store: store, mutex: PrefsMutex());
      final enricher = CoverEnricher(
        artwork: artwork,
        failures: ProbeFailureIndex(store: store, mutex: PrefsMutex()),
        folder: dir,
        readerFor: (_) => null,
        frameFor: (_) async => frame(1440, 2560),
      );
      const reel = LibraryItem(
        canonicalUrl: 'https://www.instagram.com/reel/a/',
        title: 'a',
        onServer: true,
      );
      expect(await enricher.enrich(reel), isTrue);
      final path = await artwork.artworkOf(reel.canonicalUrl);
      expect(widthOf(File(path!).readAsBytesSync()), coverWidth);
    });

    test('covers kept before are shrunk once, in place', () async {
      final dir = Directory.systemTemp.createTempSync('ember_kept_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final big = File('${dir.path}/big.jpg')
        ..writeAsBytesSync(frame(1080, 1920));
      final small = File('${dir.path}/small.jpg')
        ..writeAsBytesSync(frame(500, 500));
      final smallBytes = small.readAsBytesSync();
      expect(await shrinkKeptCovers(dir), 1);
      expect(widthOf(big.readAsBytesSync()), coverWidth);
      expect(small.readAsBytesSync(), smallBytes);
      big.writeAsBytesSync(frame(1080, 1920));
      expect(await shrinkKeptCovers(dir), 0, reason: 'done once');
    });
  });
}
