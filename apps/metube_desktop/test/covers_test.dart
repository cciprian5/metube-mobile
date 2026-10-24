import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/covers/cover_enricher.dart';
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

    CoverEnricher enricher(Map<String, Uint8List> files, {DateTime? at}) =>
        CoverEnricher(
          artwork: artwork,
          failures: failures,
          folder: Directory('${dir.path}/embedded'),
          now: () => at ?? now,
          readerFor: (item) => switch (files[item.title]) {
            final bytes? => _Ranges(bytes).call,
            null => null,
          },
        );

    test('only audio with no cover yet is asked about', () async {
      await artwork.put(clip('known').canonicalUrl, 'C:/x.jpg');
      final e = enricher({});
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
      final tomorrow = enricher({}, at: now.add(const Duration(days: 2)));
      expect(await tomorrow.candidates([clip('a')]), hasLength(1));
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
}
