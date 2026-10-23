import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show MediaShape;
import 'package:mt_ui/mt_ui.dart' show MTMediaLocation;

HistoryItem done(String url, {String? title, ItemStatus? status}) =>
    HistoryItem(
      id: url,
      canonicalUrl: url,
      title: title ?? url,
      status: status ?? ItemStatus.completed,
    );

void main() {
  List<LibraryItem> merge({
    HistoryResponse? history,
    Map<String, String> offline = const {},
    Map<String, List<String>> tags = const {},
    Map<String, String> artwork = const {},
    Map<String, MediaShape> shapes = const {},
  }) => mergeLibrary(
    history: history,
    offline: offline,
    tags: tags,
    artwork: artwork,
    shapes: shapes,
  );

  test('only finished server items join the library', () {
    final items = merge(
      history: HistoryResponse(
        done: [
          done('https://youtu.be/aaaaaaaaaaa'),
          done('https://youtu.be/bbbbbbbbbbb', status: ItemStatus.failed),
        ],
      ),
    );
    expect(
      [for (final i in items) i.canonicalUrl],
      ['https://youtu.be/aaaaaaaaaaa'],
    );
    expect(items.single.onServer, isTrue);
  });

  test('a local copy joins its server item, and one left alone stays', () {
    final items = merge(
      history: HistoryResponse(done: [done('https://youtu.be/aaaaaaaaaaa')]),
      offline: {
        'https://youtu.be/aaaaaaaaaaa': r'C:\Offline\a.mp4',
        'https://youtu.be/zzzzzzzzzzz': r'C:\Offline\Gone Clip.mp4',
      },
    );
    expect(items, hasLength(2));
    expect(items.first.location, MTMediaLocation.both);
    final gone = items.last;
    expect(gone.onServer, isFalse);
    expect(gone.title, 'Gone Clip');
  });

  test('**the guard**: an exact match is never taken by a fuzzy one', () {
    // Both addresses name the same YouTube clip; the second owns the local
    // copy exactly, so the first must not take it in passing.
    final items = merge(
      history: HistoryResponse(
        done: [
          done('https://www.youtube.com/watch?v=aaaaaaaaaaa'),
          done('https://youtu.be/aaaaaaaaaaa'),
        ],
      ),
      offline: {'https://youtu.be/aaaaaaaaaaa': r'C:\Offline\a.mp4'},
    );
    expect(items[0].localPath, isNull);
    expect(items[1].localPath, r'C:\Offline\a.mp4');
  });

  test('favourites come from the system tag, which is not a user tag', () {
    final items = merge(
      history: HistoryResponse(done: [done('https://youtu.be/aaaaaaaaaaa')]),
      tags: {
        'https://youtu.be/aaaaaaaaaaa': [
          MTConstants.favoritesSystemTag,
          'calm',
        ],
      },
    );
    expect(items.single.favorite, isTrue);
    expect(items.single.tags, ['calm']);
  });

  test('no server answer still lists every local copy', () {
    final items = merge(
      offline: {'https://youtu.be/aaaaaaaaaaa': r'C:\Offline\a.mp4'},
    );
    expect(items.single.isOffline, isTrue);
  });
}
