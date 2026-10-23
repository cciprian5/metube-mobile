import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/app.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/transcripts_data.dart';
import 'package:metube_desktop/features/library/artwork.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/shell/shell_layout.dart';
import 'package:metube_desktop/shell/shell_state.dart';
import 'package:metube_desktop/shell/window_controls.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

/// A player that records the commands it gets and plays nothing.
class FakePlayer implements MTPlayer {
  final _states = StreamController<MTPlayerState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final List<String> calls = [];

  @override
  MTPlayerState state = const MTPlayerState();
  @override
  Duration position = Duration.zero;

  /// Puts [items] in the queue as if they were playing.
  void showPlaying(List<PlaylistItem> items, {bool playing = true}) {
    state = MTPlayerState(
      items: items,
      ordered: items,
      index: 0,
      playing: playing,
      phase: MediaPlaybackState.ready,
      duration: const Duration(minutes: 3, seconds: 10),
    );
    _states.add(state);
  }

  /// As if playback reached [at].
  void reach(Duration at) {
    position = at;
    _positions.add(at);
  }

  Future<void> _note(String call) async => calls.add(call);

  @override
  Stream<MTPlayerState> get states => _states.stream;
  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Future<void> loadPreferences() => _note('loadPreferences');
  @override
  Future<void> playItems(
    List<PlaylistItem> items, {
    int startIndex = 0,
    String? playlistId,
    String? playlistName,
    bool autoPlay = true,
  }) => _note('playItems');
  @override
  Future<bool> restoreSession() async => false;
  @override
  Future<void> play() => _note('play');
  @override
  Future<void> pause() => _note('pause');
  @override
  Future<void> seek(Duration position) => _note('seek');
  @override
  Future<void> skipToNext() => _note('next');
  @override
  Future<void> skipToPrevious() => _note('previous');
  @override
  Future<void> skipToQueueItem(int index) => _note('skipTo');
  @override
  Future<void> moveQueueItem(int from, int to) => _note('move $from $to');
  @override
  Future<void> setSpeed(double speed) => _note('speed $speed');
  @override
  Future<void> setPlayMode(PlayMode mode) => _note('mode ${mode.name}');
  @override
  Future<void> setShuffle(bool value) => _note('shuffle $value');
  @override
  Future<void> stop() => _note('stop');
  @override
  Future<void> persist() => _note('persist');
  @override
  Future<void> dispose() => _note('dispose');
}

/// Everything the shell reads, with nothing behind it.
class ShellHarness {
  ShellHarness({
    this.layout = const ShellLayout(),
    this.library,
    this.server,
    this.transcripts = const {},
  });

  /// Transcripts by canonical URL, as if already on this computer.
  final Map<String, Transcript> transcripts;

  final ShellLayout layout;

  /// The unified library as if merged; null leaves the real providers,
  /// which with no server list nothing.
  final List<LibraryItem>? library;
  final ServerConfig? server;
  final player = FakePlayer();
  final controls = InertWindowControls();
  final store = MemoryKeyValueStore();
  final resolver = PlaybackSourceResolver(endpoint: ServerStreamEndpoint.none);

  Widget app() => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      playerProvider.overrideWithValue(player),
      initialShellLayoutProvider.overrideWithValue(layout),
      windowControlsProvider.overrideWithValue(controls),
      serverConfigProvider.overrideWithValue(server),
      playbackResolverProvider.overrideWithValue(resolver),
      artworkCacheProvider.overrideWithValue(NoCovers()),
      transcriptForProvider.overrideWith(
        (ref, key) async => transcripts[key.canonicalUrl],
      ),
      if (library case final items?)
        libraryItemsProvider.overrideWith((ref) async => items),
    ],
    child: const EmberApp(),
  );

  /// Sizes the test window as a Windows window of [size] logical pixels.
  static void useWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  static void useArabic(WidgetTester tester) {
    tester.platformDispatcher.localesTestValue = const [Locale('ar')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
}

PlaylistItem clip(String title) => PlaylistItem(
  canonicalUrl: 'https://example.com/$title',
  title: title,
  uploader: 'Field Notes',
  isAudio: true,
);

/// A control by the label it shows on hover, which is also what a screen
/// reader says for it.
Finder byLabel(String label) => find.byWidgetPredicate(
  (w) => w is MTShortcutTooltip && w.message == label,
  description: 'control "$label"',
);

/// A cover cache that never fetches anything, so a test touches neither
/// the network nor the disk; a card then shows its placeholder.
class NoCovers extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => const Stream.empty();
}
