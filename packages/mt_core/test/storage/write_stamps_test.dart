import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// Write stamps exist for a later merge between devices: it can only pick
/// the newer write if every write says when it happened. These tests pin
/// what gets stamped, and that an app passing no clock writes byte for
/// byte what it wrote before.
void main() {
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  var now = DateTime.utc(2026, 10, 23, 10);
  DateTime clock() => now;

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    now = DateTime.utc(2026, 10, 23, 10);
  });

  group('TagsIndex', () {
    test('each (item, tag) pair is stamped, on and off', () async {
      final tags = TagsIndex(store: store, mutex: mutex, clock: clock);

      await tags.toggleTag('u1', 'travel');
      now = now.add(const Duration(minutes: 5));
      await tags.toggleTag('u1', 'nature');

      var stamps = await tags.stamps();
      expect(stamps['u1']!['travel'], DateTime.utc(2026, 10, 23, 10));
      expect(stamps['u1']!['nature'], DateTime.utc(2026, 10, 23, 10, 5));

      // Taking a tag off is a write too; its time is what tells a merge
      // that the removal is newer than an add elsewhere.
      now = now.add(const Duration(minutes: 5));
      await tags.toggleTag('u1', 'travel');
      stamps = await tags.stamps();
      expect(stamps['u1']!['travel'], DateTime.utc(2026, 10, 23, 10, 10));
      expect(stamps['u1']!['nature'], DateTime.utc(2026, 10, 23, 10, 5));
    });

    test('a rename stamps the old and the new name on every item', () async {
      final tags = TagsIndex(store: store, mutex: mutex, clock: clock);
      await tags.toggleTag('u1', 'old');
      await tags.toggleTag('u2', 'old');
      now = now.add(const Duration(hours: 1));

      await tags.renameTag('old', 'new');

      final stamps = await tags.stamps();
      for (final url in ['u1', 'u2']) {
        expect(stamps[url]!['old'], now, reason: url);
        expect(stamps[url]!['new'], now, reason: url);
      }
    });

    test('favourites are a tag, so they are stamped the same way', () async {
      final tags = TagsIndex(store: store, mutex: mutex, clock: clock);
      await tags.toggleTag('u1', MTConstants.favoritesSystemTag);
      final stamps = await tags.stamps();
      expect(stamps['u1']![MTConstants.favoritesSystemTag], now);
    });

    test(
      '**the guard**: without a clock the index is written as before',
      () async {
        final tags = TagsIndex(store: store, mutex: mutex);
        await tags.toggleTag('u1', 'travel');

        expect(await store.keys(), ['tags_index']);
        expect(json.decode((await store.getString('tags_index'))!), {
          'u1': ['travel'],
        });
      },
    );

    test('an index from before stamping reads and edits normally', () async {
      await store.setString(
        'tags_index',
        json.encode({
          'u1': ['a'],
        }),
      );
      final tags = TagsIndex(store: store, mutex: mutex, clock: clock);

      expect(await tags.tagsOf('u1'), ['a']);
      await tags.toggleTag('u1', 'b');

      expect(await tags.tagsOf('u1'), ['a', 'b']);
      // The old pair has no stamp: unknown, which a merge treats as oldest.
      expect((await tags.stamps())['u1'], {'b': now});
    });

    test('clearing the index clears its stamps', () async {
      final tags = TagsIndex(store: store, mutex: mutex, clock: clock);
      await tags.toggleTag('u1', 'a');
      await tags.clear();
      expect(await store.keys(), isEmpty);
    });
  });

  group('PlaylistsStore', () {
    PlaylistEntry entry(String url) => PlaylistEntry(canonicalUrl: url);

    test('an edit stamps the playlist, and new members join dated', () async {
      final playlists = PlaylistsStore(
        store: store,
        mutex: mutex,
        clock: clock,
      );
      final p = await playlists.create('Trip');
      await playlists.addItems(p.id, [entry('u1')]);
      final added = now;

      now = now.add(const Duration(hours: 1));
      await playlists.addItems(p.id, [entry('u2')]);

      final saved = (await playlists.byId(p.id))!;
      expect(saved.updatedAt, now);
      expect(saved.items[0].addedAt, added);
      expect(saved.items[1].addedAt, now);
    });

    test(
      "**the guard**: renaming does not re-date the playlist's old members",
      () async {
        // A playlist written before stamping existed: its members have no
        // date, and a rename must not pretend they joined at the rename.
        await store.setString(
          PlaylistsStore.prefsKey,
          json.encode([
            {
              'id': 'p1',
              'name': 'Old',
              'createdAt': '2026-01-01T00:00:00.000',
              'pinned': false,
              'items': [
                {'canonicalUrl': 'u1'},
              ],
            },
          ]),
        );
        final playlists = PlaylistsStore(
          store: store,
          mutex: mutex,
          clock: clock,
        );

        await playlists.rename('p1', 'New');

        final saved = (await playlists.byId('p1'))!;
        expect(saved.name, 'New');
        expect(saved.updatedAt, now);
        expect(saved.items.single.addedAt, isNull);
      },
    );

    test('playing a playlist is use, not an edit', () async {
      final playlists = PlaylistsStore(
        store: store,
        mutex: mutex,
        clock: clock,
      );
      final p = await playlists.create('Trip');
      final created = now;

      now = now.add(const Duration(hours: 1));
      await playlists.touchLastPlayed(p.id, at: now);

      expect((await playlists.byId(p.id))!.updatedAt, created);
    });

    test('reordering and pinning are edits', () async {
      final playlists = PlaylistsStore(
        store: store,
        mutex: mutex,
        clock: clock,
      );
      final p = await playlists.create('Trip');
      await playlists.addItems(p.id, [entry('u1'), entry('u2')]);

      now = now.add(const Duration(hours: 1));
      await playlists.reorderItem(p.id, 0, 1);
      expect((await playlists.byId(p.id))!.updatedAt, now);

      now = now.add(const Duration(hours: 1));
      await playlists.setPinned(p.id, true);
      expect((await playlists.byId(p.id))!.updatedAt, now);
    });

    test('**the guard**: without a clock no date is written', () async {
      final playlists = PlaylistsStore(store: store, mutex: mutex);
      final p = await playlists.create('Trip');
      await playlists.addItems(p.id, [entry('u1')]);

      final raw = (await store.getString(PlaylistsStore.prefsKey))!;
      expect(raw, isNot(contains('updatedAt')));
      expect(raw, isNot(contains('addedAt')));
    });
  });
}
