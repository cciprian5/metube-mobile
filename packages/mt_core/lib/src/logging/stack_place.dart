/// Where an error happened, for the log's one line: the first few frames
/// of its stack, and the first frame from the apps' own code wherever it
/// falls.
///
/// **The first frames alone named no culprit**: an error raised inside the
/// framework (a context used after its widget left) fills them with
/// Flutter's own frames, and the log repeated four lines of framework.dart
/// a thousand times without once saying which screen did it.
String mtStackPlace(String? stack, {int frames = 4}) {
  final lines = (stack ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final shown = lines.take(frames).toList();
  if (!shown.any(_isOurs)) {
    final ours = lines.skip(frames).where(_isOurs).firstOrNull;
    if (ours != null) shown.add(ours);
  }
  return shown.join(' | ');
}

bool _isOurs(String frame) =>
    frame.contains('package:metube_') || frame.contains('package:mt_');
