import 'package:media_kit/media_kit.dart';

/// A line for the diagnostic log; [problem] marks a fault.
typedef PlayerTrace = void Function(String line, {bool problem});

/// A trace that writes nowhere, for a player with no log.
void silentTrace(String line, {bool problem = false}) {}

/// The file's kind by its name, never the name: the log is shared.
String traceKindOf(String resource) {
  final path = Uri.tryParse(resource)?.path ?? resource;
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '?' : name.substring(dot + 1).toLowerCase();
}

/// The codec, size and decoder of what [player] loaded, so a computer that
/// plays badly says which; "sound only" without a picture.
Future<String> tracePicture(Player player) async {
  final native = player.platform;
  if (native is! NativePlayer) return '';
  final codec = await native.getProperty('video-codec');
  if (codec.isEmpty) return ', sound only';
  final w = await native.getProperty('width');
  final h = await native.getProperty('height');
  final hw = await native.getProperty('hwdec-current');
  final decoder = hw.isEmpty || hw == 'no' ? 'software' : hw;
  return ', $codec ${w}x$h, decoder $decoder';
}

/// A time in the log, as the player shows it: 3:07.
String traceClock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Keeps a repeated log line from filling the log: the first one passes,
/// the same line again within [window] is counted, and the count is
/// written with the next line that passes.
class LogRepeats {
  LogRepeats({
    this.window = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration window;
  final DateTime Function() _clock;
  final _seen = <String, DateTime>{};
  int _held = 0;

  /// The line to write, or null to hold it back.
  String? pass(String line) {
    final now = _clock();
    final last = _seen[line];
    if (last != null && now.difference(last) < window) {
      _held++;
      return null;
    }
    _seen[line] = now;
    if (_seen.length > 64) _seen.remove(_seen.keys.first);
    final held = _held;
    _held = 0;
    return held == 0 ? line : '$line (after $held repeated lines)';
  }
}
