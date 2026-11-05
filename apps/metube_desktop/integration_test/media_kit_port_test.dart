import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:metube_desktop/platform/media_kit_port.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

/// The session player over the **real** media_kit engine, which a widget
/// test cannot load. Run on Windows:
///
///     flutter test integration_test -d windows
///
/// The clips are tones written here, so the test needs no server.
File _tone(Directory dir, String name, Duration length, {double hz = 440}) {
  const rate = 8000;
  final samples = rate * length.inMilliseconds ~/ 1000;
  final data = ByteData(44 + samples * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    final v = (math.sin(2 * math.pi * hz * i / rate) * 3000).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return File('${dir.path}\\$name')
    ..writeAsBytesSync(data.buffer.asUint8List());
}

PlaylistItem _item(File f) => PlaylistItem(
  canonicalUrl: 'https://x/${f.uri.pathSegments.last}',
  title: f.uri.pathSegments.last,
  localPath: f.path,
  isAudio: true,
);

Future<void> _until(bool Function() ok, {int seconds = 10}) async {
  final clock = Stopwatch()..start();
  while (!ok()) {
    if (clock.elapsed > Duration(seconds: seconds)) {
      throw TestFailure('condition not met in $seconds s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the session player drives the real engine', (tester) async {
    MediaKit.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('ember_port_');
    final a = _tone(dir, 'a.wav', const Duration(seconds: 4));
    // As long as `a` on purpose: the length stream stays silent between
    // two equal lengths, and the load must not wait on it.
    final b = _tone(dir, 'b.wav', const Duration(seconds: 4), hz: 660);
    final broken = File('${dir.path}\\broken.wav')
      ..writeAsBytesSync(List.filled(4096, 7));
    final c = _tone(dir, 'c.wav', const Duration(seconds: 3), hz: 550);

    final port = MediaKitPort.create();
    final store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    final player = MTSessionPlayer(
      port: port,
      resolver: PlaybackSourceResolver(endpoint: ServerStreamEndpoint.none),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
    );

    await player.playItems([_item(a), _item(b), _item(broken), _item(c)]);
    expect(player.state.current!.title, 'a.wav');
    expect(port.duration!.inMilliseconds, closeTo(4000, 150));
    await _until(() => port.position > const Duration(milliseconds: 500));

    await player.seek(const Duration(seconds: 2));
    await _until(() => port.position >= const Duration(seconds: 2));

    // The same length as the clip before: loads without the 30 s timeout.
    final clock = Stopwatch()..start();
    await player.skipToNext();
    expect(player.state.current!.title, 'b.wav');
    expect(clock.elapsed, lessThan(const Duration(seconds: 5)));

    // `b` ends by itself; the broken file is skipped; `c` plays.
    await _until(() => player.state.current?.title == 'c.wav', seconds: 15);
    await _until(() => port.playing);

    await player.stop();
    expect(player.state.isEmpty, isTrue);
    await player.dispose();
    dir.deleteSync(recursive: true);
  });
}
