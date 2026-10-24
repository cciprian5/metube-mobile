import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

const _a = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
const _b = 'https://www.instagram.com/reel/b/';
const _fav = MTConstants.favoritesSystemTag;

/// One device: its store, and its tags and playlists stamped by its clock.
class _Device {
  _Device(this.now);

  DateTime now;
  final store = MemoryKeyValueStore();
  final mutex = PrefsMutex();
  late final tags = TagsIndex(store: store, mutex: mutex, clock: () => now);
  late final lists = PlaylistsStore(
    store: store,
    mutex: mutex,
    clock: () => now,
  );

  Future<String> backup() => BackupService(
    store: store,
    secrets: MemorySecretStore(),
    mutex: mutex,
    variant: 'super',
  ).exportToString();

  Future<MergeResult> merge(String contents) =>
      BackupMerge(store: store, mutex: mutex).mergeFrom(contents);
}

void main() {
  final t0 = DateTime.utc(2026, 10, 20, 12);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  group('**the guard**: importing is a union, never a replacement', () {
    test(
      'a tag put on here and another put on the phone are both kept',
      () async {
        final phone = _Device(at(1));
        await phone.tags.toggleTag(_a, 'cooking');
        final desk = _Device(at(2));
        await desk.tags.toggleTag(_a, 'later');
        await desk.tags.toggleTag(_b, _fav);

        final result = await desk.merge(await phone.backup());
        expect((await desk.tags.tagsOf(_a)).toSet(), {'cooking', 'later'});
        expect(await desk.tags.tagsOf(_b), [_fav]);
        expect(result.tagged, 1);
      },
    );

    test(
      'the later change to the same pair wins, a removal included',
      () async {
        final phone = _Device(at(1));
        await phone.tags.toggleTag(_a, _fav);
        final desk = _Device(at(0));
        await desk.tags.toggleTag(_a, _fav);
        desk.now = at(5);
        await desk.tags.toggleTag(_a, _fav); // taken off here, after
        await desk.merge(await phone.backup());
        expect(await desk.tags.tagsOf(_a), isEmpty);

        phone.now = at(9);
        await phone.tags.toggleTag(_a, 'later'); // a newer pair there
        await phone.tags.toggleTag(_a, _fav); // taken off there
        phone.now = at(10);
        await phone.tags.toggleTag(_a, _fav); // and put on again, latest
        await desk.merge(await phone.backup());
        expect((await desk.tags.tagsOf(_a)).toSet(), {_fav, 'later'});
      },
    );

    test('pairs from before stamping, on either side, are all kept', () async {
      final phone = _Device(at(0));
      await phone.store.setString('tags_index', '{"$_a": ["old"]}');
      final desk = _Device(at(0));
      await desk.store.setString('tags_index', '{"$_b": ["older"]}');
      await desk.merge(await phone.backup());
      expect(await desk.tags.tagsOf(_a), ['old']);
      expect(await desk.tags.tagsOf(_b), ['older']);
    });

    test(
      'playlists: one on either side is kept, the later edit wins',
      () async {
        final phone = _Device(at(1));
        final trip = await phone.lists.create('Road trip');
        final shared = await phone.lists.create('Shared');
        // The desk had both from an earlier import.
        final desk = _Device(at(2));
        await desk.store.setString(
          PlaylistsStore.prefsKey,
          (await phone.store.getString(PlaylistsStore.prefsKey))!,
        );
        desk.now = at(3);
        await desk.lists.rename(shared.id, 'Shared, renamed here');
        final mine = await desk.lists.create('Mine');
        phone.now = at(5);
        await phone.lists.rename(trip.id, 'Road trip, renamed there');
        await phone.lists.create('New there');

        await desk.merge(await phone.backup());
        final names = {for (final p in await desk.lists.readAll()) p.name};
        expect(names, {
          'Road trip, renamed there',
          'Shared, renamed here',
          'Mine',
          'New there',
        });
        expect((await desk.lists.byId(mine.id))?.name, 'Mine');
      },
    );

    test('a resume position comes over only when it is newer', () async {
      final phone = _Device(at(0));
      await phone.store.setInt('playback_pos_$_a', 90000);
      await phone.store.setInt(
        'playback_stamp_$_a',
        at(10).millisecondsSinceEpoch,
      );
      await phone.store.setInt('playback_pos_$_b', 5000);
      await phone.store.setInt(
        'playback_stamp_$_b',
        at(1).millisecondsSinceEpoch,
      );
      final desk = _Device(at(0));
      await desk.store.setInt('playback_pos_$_b', 7000);
      await desk.store.setInt(
        'playback_stamp_$_b',
        at(5).millisecondsSinceEpoch,
      );
      final result = await desk.merge(await phone.backup());
      expect(await desk.store.getInt('playback_pos_$_a'), 90000);
      expect(await desk.store.getInt('playback_pos_$_b'), 7000);
      expect(result.positions, 1);
    });
  });

  test('nothing device-bound comes over; the addresses are only a hint, '
      'without credentials', () async {
    final phone = _Device(at(0));
    await phone.store.setString('offline_index', '{"$_a": "/storage/a.mp4"}');
    await phone.store.setString('video_sort_option', 'oldest');
    await phone.store.setString('active_url', 'http://192.168.1.5:8086');
    await phone.store.setStringList('external_urls', [
      'https://me:secret@metube.example.com',
    ]);
    final desk = _Device(at(0));
    final result = await desk.merge(await phone.backup());
    expect(await desk.store.getString('offline_index'), isNull);
    expect(await desk.store.getString('video_sort_option'), isNull);
    expect(await desk.store.getString('active_url'), isNull);
    expect(result.serverAddresses, [
      'http://192.168.1.5:8086',
      'https://metube.example.com',
    ]);
    expect(result.changedNothing, isTrue);
  });

  test('anything but an MTF backup is refused', () {
    expect(BackupMerge.looksLikeBackup('{"app":"other","prefs":{}}'), isFalse);
    expect(BackupMerge.looksLikeBackup('hello'), isFalse);
    expect(
      () => BackupMerge.readPrefs('MTFBACKUP2:abc'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('**the guard**: the export for the phone carries tags, playlists '
      'and positions, and no paths, settings or addresses', () async {
    final desk = _Device(at(1));
    await desk.tags.toggleTag(_a, _fav);
    await desk.lists.create('Desk list');
    await desk.store.setInt('playback_pos_$_a', 1000);
    await desk.store.setString('offline_index', '{"$_a": "C:/a.mp4"}');
    await desk.store.setString('ember_offline_folder', 'C:/Offline');
    await desk.store.setString('ember_server_url', 'http://nas:8086');
    final file = await BackupMerge.exportShared(desk.store, now: at(2));
    final keys = BackupMerge.readPrefs(file).keys.toSet();
    expect(keys, {
      'tags_index',
      TagsIndex.stampsKey,
      PlaylistsStore.prefsKey,
      'playback_pos_$_a',
    });

    // And a phone restores it as any backup, getting the same tags.
    final phone = _Device(at(3));
    final restore = BackupService(
      store: phone.store,
      secrets: MemorySecretStore(),
      mutex: phone.mutex,
      variant: 'super',
    );
    await restore.importFromString(file);
    expect(await phone.tags.tagsOf(_a), [_fav]);
  });
}
