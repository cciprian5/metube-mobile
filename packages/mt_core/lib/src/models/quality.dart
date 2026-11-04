import '../urls/platform_detector.dart';

/// The MeTube qualities in use.
enum Quality {
  best('best'),
  q1080('1080'),
  q720('720'),
  q480('480'),

  /// Offered by Lite alone, to keep a family phone's storage small; the
  /// other apps never list it.
  q360('360'),
  audio('audio');

  const Quality(this.wire);

  /// The value as sent in `POST /add`.
  final String wire;

  bool get isNumeric =>
      this == Quality.q1080 ||
      this == Quality.q720 ||
      this == Quality.q480 ||
      this == Quality.q360;

  /// **The platform rule:** a numeric quality is a height ceiling, sent to
  /// every video platform; an audio-only one gets `best`. Outside YouTube a
  /// site may list no heights at all, so the download engine retries such a
  /// refusal at `best` once. `audio` and `best` are available everywhere.
  Quality applyRule(String url) {
    if (!isNumeric) return this;
    return MediaPlatform.detect(url).isAudioOnly ? Quality.best : this;
  }

  /// Tolerant reading of a stored or incoming value; anything unknown
  /// becomes `best`.
  static Quality fromWire(String? value) {
    final v = value?.trim().toLowerCase();
    for (final q in Quality.values) {
      if (q.wire == v) return q;
    }
    return Quality.best;
  }
}
