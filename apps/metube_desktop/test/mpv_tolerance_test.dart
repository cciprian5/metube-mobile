import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:metube_desktop/platform/media_kit_port.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

/// **"It reaches a quarter and starts over until it stops"**, seen on
/// another computer. Two causes: every error line mpv logs reached the
/// player as a failure, and a dropped connection reads as the end of the
/// file. Both run through the real [Player] here, over an engine the test
/// drives, so nothing needs libmpv.
class _Engine extends PlatformPlayer {
  _Engine() : super(configuration: const PlayerConfiguration());

  final List<Duration?> opened = [];
  String? failOpenWith;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened.add((playable as Media).start);
    if (failOpenWith case final error?) {
      errorController.add(error);
      return;
    }
    const length = Duration(minutes: 4);
    state = state.copyWith(duration: length, completed: false);
    durationController.add(length);
    completedController.add(false);
  }

  @override
  Future<void> play() async => state = state.copyWith(playing: true);
  @override
  Future<void> pause() async => state = state.copyWith(playing: false);
  @override
  Future<void> stop() async => state = state.copyWith(playing: false);
  @override
  Future<void> seek(Duration duration) async =>
      state = state.copyWith(position: duration);
  @override
  Future<void> setRate(double rate) async => state = state.copyWith(rate: rate);

  void errorLine(String text) => errorController.add(text);

  /// mpv reporting the end of the file, with the clock at [at].
  void endsAt(Duration at) {
    state = state.copyWith(position: at, completed: true);
    completedController.add(true);
  }
}

void main() {
  final remote = PlaybackSource(
    origin: PlaybackOrigin.stream,
    uri: Uri.parse('https://srv/download/a.mp4'),
  );
  final local = PlaybackSource(
    origin: PlaybackOrigin.local,
    uri: Uri.file(r'C:\clips\a.mp4', windows: true),
  );

  late _Engine engine;
  late MediaKitPort port;
  late List<Object> failures;
  late List<MediaPlaybackState> phases;
  late bool playing;
  late int asked;

  Future<void> afterJudging() => Future<void>.delayed(
    MediaKitPort.judgeAfter + const Duration(milliseconds: 200),
  );

  setUp(() {
    engine = _Engine();
    playing = true;
    asked = 0;
    port = MediaKitPort.over(
      Player(platformPlayer: engine),
      stillPlaying: () async {
        asked++;
        return playing;
      },
    );
    failures = [];
    phases = [];
    port.errors.listen(failures.add);
    port.stateStream.listen(phases.add);
  });

  tearDown(() => port.dispose());

  group('an error line', () {
    test('**the guard**: leaves a clip that keeps playing alone', () async {
      await port.setSource(remote);
      engine.errorLine('Error decoding audio frame');
      await afterJudging();
      expect(asked, 1, reason: 'the engine was looked at');
      expect(failures, isEmpty);
      expect(engine.opened, hasLength(1), reason: 'nothing reloaded');
    });

    test('a flood of them is judged once', () async {
      await port.setSource(remote);
      for (var i = 0; i < 200; i++) {
        engine.errorLine('frame dropped $i');
      }
      await afterJudging();
      expect(asked, 1);
      expect(failures, isEmpty);
    });

    test(
      'is a failure only when playback has really stopped, and once',
      () async {
        await port.setSource(remote);
        playing = false;
        engine
          ..errorLine('Failed to recognize file format')
          ..errorLine('the same again');
        await pumpEventQueue();
        expect(failures, isEmpty, reason: 'not before it is judged');
        await afterJudging();
        expect(failures, ['Failed to recognize file format']);
      },
    );

    test('from the last clip says nothing about the next', () async {
      await port.setSource(remote);
      playing = false;
      engine.errorLine('from the clip being left');
      await pumpEventQueue();
      await port.setSource(local);
      await afterJudging();
      expect(failures, isEmpty);
    });

    test('during a load is for the load to judge', () async {
      playing = false;
      engine.failOpenWith = 'Failed to open';
      await expectLater(port.setSource(remote), throwsStateError);
      await afterJudging();
      expect(failures, isEmpty, reason: 'one failure, thrown, not two');
    });
  });

  group('the end of a stream', () {
    test('**the guard**: well before its length is a failure, not the '
        'clip ending', () async {
      await port.setSource(remote);
      engine.endsAt(const Duration(minutes: 1));
      await pumpEventQueue();
      expect(failures, ['ended early']);
      expect(phases, isNot(contains(MediaPlaybackState.completed)));
    });

    test('near its length is the clip ending', () async {
      await port.setSource(remote);
      engine.endsAt(const Duration(minutes: 3, seconds: 57));
      await pumpEventQueue();
      expect(failures, isEmpty);
      expect(phases, contains(MediaPlaybackState.completed));
    });

    test('of a file on this computer is the clip ending, wherever the '
        'clock stopped', () async {
      await port.setSource(local);
      engine.endsAt(const Duration(minutes: 1));
      await pumpEventQueue();
      expect(failures, isEmpty);
      expect(phases, contains(MediaPlaybackState.completed));
    });
  });

  group('with the session player on top', () {
    late MTSessionPlayer session;

    setUp(() {
      final store = MemoryKeyValueStore();
      final mutex = PrefsMutex();
      session = MTSessionPlayer(
        port: port,
        resolver: PlaybackSourceResolver(
          endpoint: ServerStreamEndpoint(
            buildUrl: (name) => 'https://srv/download/$name',
            headers: const {},
          ),
        ),
        positions: PlaybackPositionStore(store: store, mutex: mutex),
        prefs: PlaybackPrefs(store: store, mutex: mutex),
        stateStore: AudioStateStore(store: store, mutex: mutex),
        saveInterval: const Duration(hours: 1),
        networkRetryBackoff: const [Duration.zero, Duration.zero],
      );
    });

    tearDown(() => session.dispose());

    final clip = PlaylistItem(
      canonicalUrl: 'https://x/a',
      title: 'a',
      serverFilename: 'a.mp4',
      isAudio: true,
      duration: const Duration(minutes: 4),
    );

    test('an error line at a quarter does not restart the clip', () async {
      await session.playItems([clip]);
      engine.state = engine.state.copyWith(
        position: const Duration(minutes: 1),
      );
      engine.errorLine('hardware decoder fell back to software');
      await afterJudging();
      expect(engine.opened, hasLength(1));
      expect(engine.state.position, const Duration(minutes: 1));
    });

    test('**the guard**: a stream dropped at a quarter picks up there, not '
        'at the start', () async {
      await session.playItems([clip]);
      engine.endsAt(const Duration(minutes: 1));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(engine.opened, hasLength(2));
      expect(engine.opened.last, const Duration(minutes: 1));
    });
  });
}
