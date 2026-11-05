import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

const _a = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
const _b = 'https://www.instagram.com/reel/b/';

void main() {
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  var now = DateTime.utc(2026, 10, 25, 9);

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    now = DateTime.utc(2026, 10, 25, 9);
  });

  PlaylistsStore stamped() =>
      PlaylistsStore(store: store, mutex: mutex, clock: () => now);

  group('saved lists', () {
    test('**the guard**: a deleted list and a clip taken out of one leave '
        'their time behind', () async {
      final lists = stamped();
      final evening = await lists.create(
        'Evening',
        items: const [
          PlaylistEntry(canonicalUrl: _a),
          PlaylistEntry(canonicalUrl: _b),
        ],
      );
      final spare = await lists.create('Spare');
      now = now.add(const Duration(minutes: 5));
      await lists.removeItem(evening.id, _b);
      await lists.delete(spare.id);

      final gone = await lists.removals();
      final at = now.millisecondsSinceEpoch;
      expect(gone.members, {
        evening.id: {_b: at},
      });
      expect(gone.lists, {spare.id: at});
    });

    test(
      'a clip put back clears its record; the list format is unchanged',
      () async {
        final lists = stamped();
        final evening = await lists.create(
          'Evening',
          items: const [PlaylistEntry(canonicalUrl: _a)],
        );
        await lists.removeItem(evening.id, _a);
        await lists.addItems(evening.id, const [
          PlaylistEntry(canonicalUrl: _a),
        ]);
        expect((await lists.removals()).isEmpty, isTrue);
        expect(
          await store.getString(PlaylistsStore.prefsKey),
          isNot(contains('removed')),
        );
      },
    );

    test("**the guard**: an app that does not stamp (Lite) never writes the "
        'record', () async {
      final lists = PlaylistsStore(store: store, mutex: mutex);
      final evening = await lists.create(
        'Evening',
        items: const [PlaylistEntry(canonicalUrl: _a)],
      );
      await lists.removeItem(evening.id, _a);
      await lists.delete(evening.id);
      expect(await store.keys(), isNot(contains(PlaylistRemovals.prefsKey)));
    });

    test(
      'records older than the cut-off are forgotten, newer ones kept',
      () async {
        final lists = stamped();
        final old = await lists.create('Old');
        await lists.delete(old.id);
        now = now.add(const Duration(days: 100));
        final recent = await lists.create('Recent');
        await lists.delete(recent.id);
        await lists.forgetRemovalsBefore(
          now.subtract(const Duration(days: 90)),
        );
        expect((await lists.removals()).lists.keys, [recent.id]);
      },
    );
  });

  group('tags', () {
    test('a tag taken off long ago is forgotten; a tag still on keeps its '
        'stamp', () async {
      final tags = TagsIndex(store: store, mutex: mutex, clock: () => now);
      await tags.toggleTag(_a, 'calm');
      await tags.toggleTag(_a, 'travel');
      await tags.toggleTag(_a, 'travel'); // taken off at once
      now = now.add(const Duration(days: 100));
      await tags.toggleTag(_b, 'focus');
      await tags.toggleTag(_b, 'focus'); // taken off recently

      await tags.forgetRemovalsBefore(now.subtract(const Duration(days: 90)));
      final stamps = await tags.stamps();
      expect(stamps[_a]!.keys, ['calm']);
      expect(stamps[_b]!.keys, ['focus']);
      expect(await tags.tagsOf(_a), ['calm']);
    });
  });
}
