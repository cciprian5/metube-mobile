import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// A cover's value can come from the server's history; a path there must
/// never be read or deleted as the app's own file.
void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('art_paths_'));
  tearDown(() => root.deleteSync(recursive: true));

  String sep(List<String> parts) => parts.join(Platform.pathSeparator);

  test('**the guard**: a server cover that is a path on this device is '
      'not taken as the cover', () {
    final item = HistoryItem.fromJson({
      'url': 'https://vimeo.com/123',
      'title': 'x',
      'thumbnail': '/data/user/0/com.yasir.metubelite/shared_prefs/a.xml',
    });
    expect(item.thumbnail, isNull);
    final web = HistoryItem.fromJson({
      'url': 'https://vimeo.com/123',
      'title': 'x',
      'thumbnail': 'https://i.vimeocdn.com/video/1.jpg',
    });
    expect(web.thumbnail, 'https://i.vimeocdn.com/video/1.jpg');
  });

  test('**the guard**: removing an entry deletes its file only from the '
      "app's own folder", () async {
    final own = Directory(sep([root.path, 'files']))..createSync();
    final thumb = File(sep([own.path, 'thumbs', 'a.jpg']))
      ..createSync(recursive: true);
    final elsewhere = File(sep([root.path, 'prefs.xml']))..createSync();
    final climbing = sep([own.path, 'thumbs', '..', '..', 'prefs.xml']);
    final index = ArtworkIndex(
      store: MemoryKeyValueStore(),
      mutex: PrefsMutex(),
      ownFolder: () async => own.path,
    );
    await index.put('https://a', thumb.path);
    await index.put('https://b', elsewhere.path);
    await index.put('https://c', climbing);

    await index.removeKeysAndFiles(['https://a', 'https://b', 'https://c']);
    expect(thumb.existsSync(), isFalse);
    expect(elsewhere.existsSync(), isTrue);
    expect(await index.readAll(), isEmpty);
  });

  test('when the folder cannot be told, nothing is deleted and the '
      'entries still go', () async {
    final file = File(sep([root.path, 'a.jpg']))..createSync();
    final index = ArtworkIndex(
      store: MemoryKeyValueStore(),
      mutex: PrefsMutex(),
      ownFolder: () async => throw const FileSystemException('no plugin'),
    );
    await index.put('https://a', file.path);
    await index.removeKeysAndFiles(['https://a']);
    expect(file.existsSync(), isTrue);
    expect(await index.readAll(), isEmpty);
  });

  test('inside means below the folder, by whole parts', () {
    expect(ArtworkIndex.isInside('/f/thumbs/a.jpg', '/f'), isTrue);
    expect(ArtworkIndex.isInside(r'C:\A\files\t\a.jpg', 'c:/a/files'), isTrue);
    expect(ArtworkIndex.isInside('/files2/a.jpg', '/files'), isFalse);
    expect(ArtworkIndex.isInside('/f', '/f'), isFalse);
    expect(ArtworkIndex.isInside('/f/../x', '/f'), isFalse);
  });
}
