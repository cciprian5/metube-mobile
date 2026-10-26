import 'dart:async';
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:metube_desktop/features/listening/listening_room.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import '../test/support/shell_harness.dart';

/// **How smoothly the listening room draws**, measured by the engine on
/// this computer's own screen: the room open on a sound playing, its embers
/// moving and its lines gliding every few seconds. A widget test cannot
/// tell, as it draws nothing. Run in profile mode, as a release draws:
///
///     flutter run --profile -d windows -t integration_test/listening_frames.dart
///
/// It prints the frame rate and frame times after ten seconds, and exits.
const _url = 'https://youtu.be/sssssssssss';
// Time to maximize the window by hand before measuring.
const _warmUp = Duration(seconds: 8);
const _measured = Duration(seconds: 10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final item = LibraryItem(
    canonicalUrl: _url,
    title: 'هل تفعل هذا؟ إليك 3 سمات تكشفها عادة ترتيب الكرسي قبل المغادرة',
    uploader: 'قناة المختبر',
    onServer: true,
    isAudio: true,
    serverFilename: 'clip.mp3',
    timestamp: DateTime(2026, 10, 20),
  );
  final h = ShellHarness(
    library: [item],
    server: ServerConfig(baseUrl: 'http://nas:8081'),
    transcripts: {
      _url: Transcript(
        canonicalUrl: _url,
        language: 'ar',
        source: 'sidecar',
        fetchedAt: DateTime(2026, 10, 24),
        segments: [
          for (var i = 0; i < 300; i++)
            TranscriptSegment(
              start: Duration(seconds: i * 3),
              end: Duration(seconds: i * 3 + 3),
              text: i.isEven
                  ? 'في اللحظة اللي يخلص فيها الشخص الاني من الطاولة'
                  : 'The second line of the pair, said in English here',
            ),
        ],
      ),
    },
    overrides: [listeningProvider.overrideWith((ref) => true)],
  );
  runApp(h.app());
  h.player.showPlaying([toPlaylistItem(item)]);

  // A new line every three seconds, as speech goes.
  var at = 0;
  final lines = Timer.periodic(const Duration(seconds: 3), (_) {
    at += 3;
    h.player.reach(Duration(seconds: at));
  });

  await Future<void>.delayed(_warmUp);
  final frames = <FrameTiming>[];
  void keep(List<FrameTiming> timings) => frames.addAll(timings);
  SchedulerBinding.instance.addTimingsCallback(keep);
  await Future<void>.delayed(_measured);
  SchedulerBinding.instance.removeTimingsCallback(keep);
  lines.cancel();

  double ms(Duration d) => d.inMicroseconds / 1000;
  String spread(List<double> values) {
    values.sort();
    double at(double q) => values[((values.length - 1) * q).round()];
    return 'median ${at(0.5).toStringAsFixed(2)} ms, '
        'p90 ${at(0.9).toStringAsFixed(2)}, p99 ${at(0.99).toStringAsFixed(2)}, '
        'max ${values.last.toStringAsFixed(2)}';
  }

  final seconds = _measured.inMilliseconds / 1000;
  final late = frames.where(
    (f) => ms(f.buildDuration) > 16.7 || ms(f.rasterDuration) > 16.7,
  );
  stdout
    ..writeln(
      'FRAMES ${frames.length} in ${seconds}s = '
      '${(frames.length / seconds).toStringAsFixed(1)} a second',
    )
    ..writeln(
      'FRAMES build: ${spread([for (final f in frames) ms(f.buildDuration)])}',
    )
    ..writeln(
      'FRAMES raster: ${spread([for (final f in frames) ms(f.rasterDuration)])}',
    )
    ..writeln('FRAMES over 16.7 ms: ${late.length}');
  exit(0);
}
