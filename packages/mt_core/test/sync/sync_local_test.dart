import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

const _trip = 'https://www.youtube.com/watch?v=trip0000000';
const _talk = 'https://www.instagram.com/reel/talk/';
const _fav = MTConstants.favoritesSystemTag;

/// One device: its own storage, its stores stamped by its own clock, and
/// its name in the sync folder.
class _Device {
  _Device(this.id, this.now);

  final String id;
  DateTime now;
  final store = MemoryKeyValueStore();
  final mutex = PrefsMutex();
  late final tags = TagsIndex(store: store, mutex: mutex, clock: () => now);
  late final lists = PlaylistsStore(
    store: store,
    mutex: mutex,
    clock: () => now,
  );
  late final local = SyncLocal(
    store: store,
    mutex: mutex,
    searchesKey: 'ember_saved_searches',
  );

  Future<void> position(String url, int ms) async {
    await store.setInt('playback_pos_$url', ms);
    await store.setInt('playback_stamp_$url', now.millisecondsSinceEpoch);
  }

  /// Reads the others' files, merges, writes its storage and its own file.
  Future<SyncOutcome> sync(SyncFolder folder) async {
    final at = now.millisecondsSinceEpoch;
    final outcome = SyncMerge.forDevice(
      mine: await local.read(
        deviceId: id,
        deviceKind: id.split('-').first,
        writtenAt: at,
      ),
      others: [for (final d in await folder.others(id)) d.snapshot],
      now: at,
    );
    await local.apply(outcome.snapshot);
    await folder.write(outcome.snapshot);
    return outcome;
  }
}

void main() {
  late Directory root;
  late SyncFolder folder;
  final t0 = DateTime.utc(2026, 10, 25, 9);

  setUp(() {
    root = Directory.systemTemp.createTempSync('mt_sync_');
    folder = SyncFolder(root.path);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('**the guard**: a tag, a favourite, a list and a position made on one '
      'device reach the other through the folder', () async {
    final phone = _Device('phone-a1b2', t0);
    final ember = _Device('ember-c3d4', t0);
    await phone.tags.toggleTag(_trip, 'travel');
    await phone.tags.toggleTag(_trip, _fav);
    final evening = await phone.lists.create(
      'Evening',
      items: const [PlaylistEntry(canonicalUrl: _trip, cachedTitle: 'Trip')],
    );
    await phone.position(_trip, 65000);
    await phone.sync(folder);

    await ember.sync(folder);
    expect((await ember.tags.tagsOf(_trip)).toSet(), {'travel', _fav});
    final got = (await ember.lists.byId(evening.id))!;
    expect(got.name, 'Evening');
    expect(got.items.single.cachedTitle, 'Trip');
    expect(await ember.store.getInt('playback_pos_$_trip'), 65000);
  });

  test('**the guard**: a list deleted on one device is not brought back by '
      'the other', () async {
    final phone = _Device('phone-a1b2', t0);
    final ember = _Device('ember-c3d4', t0);
    final spare = await phone.lists.create('Spare');
    await phone.sync(folder);
    await ember.sync(folder);
    expect(await ember.lists.byId(spare.id), isNotNull);

    ember.now = t0.add(const Duration(minutes: 5));
    await ember.lists.delete(spare.id);
    await ember.sync(folder);
    phone.now = t0.add(const Duration(minutes: 6));
    await phone.sync(folder);
    expect(await phone.lists.byId(spare.id), isNull);
    // And it stays gone when the phone writes back.
    await ember.sync(folder);
    expect(await ember.lists.byId(spare.id), isNull);
  });

  test('tags taken off and put on from both sides meet per pair', () async {
    final phone = _Device('phone-a1b2', t0);
    final ember = _Device('ember-c3d4', t0);
    await phone.tags.toggleTag(_talk, 'calm');
    await phone.sync(folder);
    await ember.sync(folder);

    phone.now = t0.add(const Duration(minutes: 1));
    await phone.tags.toggleTag(_talk, 'travel');
    ember.now = t0.add(const Duration(minutes: 2));
    await ember.tags.toggleTag(_talk, 'calm'); // taken off
    await ember.tags.toggleTag(_talk, 'nature');
    await phone.sync(folder);
    await ember.sync(folder);
    await phone.sync(folder);

    for (final device in [phone, ember]) {
      expect((await device.tags.tagsOf(_talk)).toSet(), {'travel', 'nature'});
    }
  });

  test(
    'nothing changes on a second pass, and nothing is written for it',
    () async {
      final phone = _Device('phone-a1b2', t0);
      await phone.tags.toggleTag(_trip, 'travel');
      await phone.lists.create('Evening');
      await phone.sync(folder);
      final mine = await phone.local.read(
        deviceId: phone.id,
        deviceKind: 'phone',
      );
      expect(await phone.local.apply(SyncMerge.merge(mine, mine)), isFalse);
    },
  );

  test(
    'a conflict copy and a half-written file are not read as devices',
    () async {
      final phone = _Device('phone-a1b2', t0);
      await phone.tags.toggleTag(_trip, 'travel');
      await phone.sync(folder);
      await Directory('${folder.root.path}/phone-a1b2.sync-conflict-20261025-1')
          .create();
      await File('${folder.root.path}/phone-a1b2/library.sync-conflict-x.json')
          .writeAsString('{}');
      final others = await folder.others('ember-c3d4');
      expect(others.map((d) => d.id), ['phone-a1b2']);
    },
  );

  test('saved searches travel with their removals', () async {
    final ember = _Device('ember-c3d4', t0);
    final laptop = _Device('ember-lap1', t0);
    final t1 = t0.millisecondsSinceEpoch - 60000;
    final t2 = t0.millisecondsSinceEpoch - 1000;
    await ember.store.setString(
      'ember_saved_searches',
      '[{"id":"s1","name":"Pools","query":"pool","at":$t1},'
          '{"id":"s2","name":"Old","query":"old","at":$t1}]',
    );
    await ember.sync(folder);
    await laptop.sync(folder);
    await laptop.store.setString(
      'ember_saved_searches',
      '[{"id":"s1","name":"Pools","query":"pool","at":$t1}]',
    );
    await laptop.store.setString('ember_saved_searches_removed', '{"s2":$t2}');
    await laptop.sync(folder);
    await ember.sync(folder);
    expect(
      await ember.store.getString('ember_saved_searches'),
      isNot(contains('s2')),
    );
  });
}
