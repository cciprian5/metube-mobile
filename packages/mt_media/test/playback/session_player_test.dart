import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'fake_player_port.dart';

/// The Windows player keeps the phone player's rules one for one; these
/// pin each of them on a fake engine, with no playback package involved.
PlaylistItem _item(String id, {String? localPath, Duration? duration}) =>
    PlaylistItem(
      canonicalUrl: 'https://x/$id',
      title: id,
      serverFilename: '$id.mp3',
      localPath: localPath,
      isAudio: true,
      duration: duration,
    );

String _url(String id) => 'https://srv/download/$id.mp3';

void main() {
  late FakePlayerPort port;
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  late PlaybackPositionStore positions;
  late AudioStateStore states;
  late PlaybackPrefs prefs;
  late MTSessionPlayer player;
  late Set<String> existingFiles;

  MTSessionPlayer build({List<Duration> retries = const []}) {
    port = FakePlayerPort();
    positions = PlaybackPositionStore(store: store, mutex: mutex);
    prefs = PlaybackPrefs(store: store, mutex: mutex);
    states = AudioStateStore(store: store, mutex: mutex);
    return MTSessionPlayer(
      port: port,
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {'Authorization': 'Basic k'},
        ),
        fileExists: existingFiles.contains,
      ),
      positions: positions,
      prefs: prefs,
      stateStore: states,
      // The periodic save is triggered by hand in these tests.
      saveInterval: const Duration(hours: 1),
      networkRetryBackoff: retries,
    );
  }

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    existingFiles = {};
    player = build();
  });

  tearDown(() => player.dispose());

  group('the golden rule', () {
    test('it streams with the credentials when there is no copy', () async {
      await player.playItems([_item('a')]);
      expect(port.loaded.single.uri.toString(), _url('a'));
      expect(port.loaded.single.headers['Authorization'], 'Basic k');
      expect(player.state.playing, isTrue);
    });

    test('a local copy plays from disk', () async {
      existingFiles.add(r'C:\clips\a.mp3');
      await player.playItems([_item('a', localPath: r'C:\clips\a.mp3')]);
      expect(port.loaded.single.isLocal, isTrue);
    });
  });

  group('the queue and the modes', () {
    test('an item that ends plays the next one', () async {
      await player.playItems([_item('a'), _item('b')]);
      port.emitCompleted();
      await pumpEventQueue();
      expect(player.state.current!.title, 'b');
    });

    test('stop-at-end rests on the first frame of the item', () async {
      await player.playItems([_item('a'), _item('b')]);
      await player.setPlayMode(PlayMode.stopAtEnd);
      port.emitCompleted();
      await pumpEventQueue();
      expect(player.state.current!.title, 'a');
      expect(port.calls.sublist(port.calls.length - 2), [
        'pause',
        'seek(0:00:00.000000)',
      ]);
    });

    test('repeat-one plays the same item again', () async {
      await player.playItems([_item('a'), _item('b')]);
      await player.setPlayMode(PlayMode.repeatOne);
      port.emitCompleted();
      await pumpEventQueue();
      expect(player.state.current!.title, 'a');
      expect(port.calls.last, 'play');
    });

    test('repeat-all wraps from the last item to the first', () async {
      await player.playItems([_item('a'), _item('b')], startIndex: 1);
      await player.setPlayMode(PlayMode.repeatAll);
      port.emitCompleted();
      await pumpEventQueue();
      expect(player.state.current!.title, 'a');
    });

    test('"previous" restarts past three seconds, goes back within', () async {
      await player.playItems([_item('a'), _item('b')], startIndex: 1);
      port.position = const Duration(seconds: 40);
      await player.skipToPrevious();
      expect(player.state.current!.title, 'b');
      expect(port.position, Duration.zero);

      await player.skipToPrevious();
      expect(player.state.current!.title, 'a');
    });
  });

  group('failures', () {
    test('a broken item is skipped', () async {
      port.failing.add(_url('a'));
      await player.playItems([_item('a'), _item('b')]);
      expect(player.state.current!.title, 'b');
    });

    test('when every item fails it stops instead of looping', () async {
      port.failing.addAll([_url('a'), _url('b'), _url('c')]);
      await player.playItems([_item('a'), _item('b'), _item('c')]);
      expect(player.state.isEmpty, isTrue);
      expect(await states.read(), isNull);
    });

    test('a dropped stream is retried before it is skipped', () async {
      await player.dispose();
      player = build(retries: const [Duration.zero]);
      port.failingTimes[_url('a')] = 1;
      await player.playItems([_item('a'), _item('b')]);
      expect(player.state.current!.title, 'a');
      expect(port.loaded.single.uri.toString(), _url('a'));
    });
  });

  group('continuity', () {
    test('only a long item resumes where it was left', () async {
      await positions.save('https://x/song', const Duration(minutes: 1));
      await positions.save('https://x/talk', const Duration(minutes: 7));
      await player.playItems([
        _item('song', duration: const Duration(minutes: 3)),
      ]);
      expect(port.position, Duration.zero);

      await player.playItems([
        _item('talk', duration: const Duration(minutes: 40)),
      ]);
      expect(port.position, const Duration(minutes: 7));
    });

    test(
      'a restored session continues exactly and never plays by itself',
      () async {
        await player.playItems([_item('a'), _item('b')], startIndex: 1);
        port.position = const Duration(seconds: 25);
        await player.persist();
        await player.dispose();

        player = build();
        expect(await player.restoreSession(), isTrue);
        expect(player.state.current!.title, 'b');
        expect(port.position, const Duration(seconds: 25));
        expect(port.calls, isNot(contains('play')));
      },
    );

    test('play with nothing queued brings the saved list back', () async {
      await player.playItems([_item('a')]);
      await player.persist();
      await player.dispose();

      player = build();
      await player.play();
      expect(player.state.current!.title, 'a');
      expect(port.calls.last, 'play');
    });

    test('a closed session stays closed', () async {
      await player.playItems([_item('a')]);
      await player.stop();
      expect(player.state.isEmpty, isTrue);
      await player.play();
      expect(player.state.isEmpty, isTrue);
    });
  });

  test('**the guard**: a stop during a load does not bring it back', () async {
    final pending = player.playItems([_item('a')]);
    await player.stop();
    await pending;
    expect(player.state.isEmpty, isTrue);
    expect(port.playing, isFalse);
  });

  test('every change reaches the states stream', () async {
    final seen = <MTPlayerState>[];
    final sub = player.states.listen(seen.add);
    await player.playItems([_item('a'), _item('b')]);
    await player.setShuffle(true);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.last.shuffle, isTrue);
    expect(seen.last.items, hasLength(2));
  });

  test('**the guard**: the shared player knows no playback package', () {
    // The Windows app takes this player; a phone package imported here
    // would follow it there.
    for (final name in [
      'mt_player.dart',
      'mt_session_player.dart',
      'mt_session_player_flow.dart',
    ]) {
      final src = File('lib/src/playback/$name').readAsStringSync();
      for (final banned in ['audio_service', 'just_audio', 'video_player']) {
        expect(src, isNot(contains('package:$banned')), reason: name);
      }
    }
  });
}
