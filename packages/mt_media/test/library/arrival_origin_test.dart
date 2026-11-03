import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

ChannelSubscription _sub(
  String name,
  String url, {
  bool enabled = true,
}) => ChannelSubscription.fromJson({
  'id': name,
  'name': name,
  'url': url,
  'enabled': enabled,
  'check_interval_minutes': 60,
  'seen_count': 0,
})!;

ClipAuthorLookup _says(String? name, String? url) =>
    (_) async => (name: name, url: url);

Future<({String? name, String? url})?> _silent(String _) async => null;

void main() {
  final eric = _sub('Eric Tech - Videos', 'https://www.youtube.com/@erictech');
  const clip = 'https://www.youtube.com/watch?v=abc';
  const reel = 'https://www.instagram.com/reel/abc/';

  group('the origin of a clip', () {
    test('**the guard**: a platform nothing is followed on can never have '
        'come from a subscription, and nobody is asked', () async {
      var asked = false;
      final origin = await arrivalOrigin(
        reel,
        following: [eric],
        author: (_) async {
          asked = true;
          return null;
        },
      );
      expect(origin, ArrivalOrigin.notFollowed);
      expect(asked, isFalse);
    });

    test('nothing followed means nothing arrived by subscription', () async {
      expect(
        await arrivalOrigin(clip, following: const [], author: _silent),
        ArrivalOrigin.notFollowed,
      );
    });

    test('a paused channel brings nothing', () async {
      final paused = _sub(
        'Eric',
        'https://www.youtube.com/@erictech',
        enabled: false,
      );
      expect(
        await arrivalOrigin(clip, following: [paused], author: _silent),
        ArrivalOrigin.notFollowed,
      );
    });

    test('**the guard**: a clip by another channel on the same platform, '
        'added from another device, is not called a subscription', () async {
      expect(
        await arrivalOrigin(
          clip,
          following: [eric],
          author: _says('Someone', 'https://www.youtube.com/@someone'),
        ),
        ArrivalOrigin.notFollowed,
      );
    });

    test('the address matches whichever host and tab it was written with', () async {
      final tabbed = _sub(
        'Renamed',
        'https://m.youtube.com/@ERICTECH/videos',
      );
      expect(
        await arrivalOrigin(
          clip,
          following: [tabbed],
          author: _says('Eric', 'https://www.youtube.com/@erictech'),
        ),
        ArrivalOrigin.followed,
      );
    });

    test('a channel followed by its id matches on the name', () async {
      final byId = _sub(
        'Uploads from Eric Tech',
        'https://www.youtube.com/channel/UC123',
      );
      expect(
        await arrivalOrigin(
          clip,
          following: [byId],
          author: _says('Eric Tech', 'https://www.youtube.com/@erictech'),
        ),
        ArrivalOrigin.followed,
      );
    });

    test('what the server names needs no question', () async {
      expect(
        await arrivalOrigin(
          clip,
          uploader: 'Eric Tech',
          following: [eric],
          author: (_) => throw StateError('not asked'),
        ),
        ArrivalOrigin.followed,
      );
    });

    test('no answer leaves it unknown, not ruled out', () async {
      expect(
        await arrivalOrigin(clip, following: [eric], author: _silent),
        ArrivalOrigin.unknown,
      );
    });

    test('a followed playlist holds other authors, so one proves nothing', () async {
      final list = _sub(
        'Mix',
        'https://www.youtube.com/playlist?list=PL123',
      );
      expect(
        await arrivalOrigin(
          clip,
          following: [list],
          author: _says('Someone', 'https://www.youtube.com/@someone'),
        ),
        ArrivalOrigin.unknown,
      );
    });
  });

  group('sorting a batch', () {
    test('keeps what is worth a notice and drops the rest', () async {
      final sorted = await sortArrivals<String>(
        ['$clip&1', '$clip&2', reel],
        urlOf: (url) => url,
        following: [eric],
        author: (url) async => url.endsWith('&1')
            ? (name: 'Eric Tech', url: null)
            : null,
      );
      expect(sorted.followed, ['$clip&1']);
      expect(sorted.unknown, ['$clip&2']);
    });

    test('a long absence asks only so many, and the rest stay unknown', () async {
      var asked = 0;
      final sorted = await sortArrivals<String>(
        [for (var i = 0; i < 30; i++) '$clip&$i'],
        urlOf: (url) => url,
        following: [eric],
        maxLookups: 5,
        author: (_) async {
          asked++;
          return (name: 'Eric Tech', url: null);
        },
      );
      expect(asked, 5);
      expect(sorted.followed, hasLength(5));
      expect(sorted.unknown, hasLength(25));
    });
  });

  group('what was sent from here', () {
    late MemoryKeyValueStore store;
    late PrefsMutex mutex;

    UnfinishedSends sends() =>
        UnfinishedSends(store: store, mutex: mutex, key: 'k');

    setUp(() {
      store = MemoryKeyValueStore();
      mutex = PrefsMutex();
    });

    test('**the guard**: it survives the app closing', () async {
      await sends().note('a', finished: false);
      expect(await sends().all(), {'a'});
    });

    test('what the server finished is not kept', () async {
      await sends().note('a', finished: true);
      expect(await sends().all(), isEmpty);
    });

    test('settling forgets what finished and keeps the rest', () async {
      final kept = sends();
      await kept.note('a', finished: false);
      await kept.note('b', finished: false);
      await kept.settle(['a', 'z']);
      expect(await sends().all(), {'b'});
    });
  });
}
