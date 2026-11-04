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
  /// every video platform. Outside YouTube a site may list no heights at
  /// all, so the download engine retries such a refusal at `best` once.
  ///
  /// An audio-only platform gets `audio` whatever was chosen: there is no
  /// picture to pick a height or a codec for, and only the audio path asks
  /// the server to embed the track's cover. `best` there was sent as a video
  /// download, which kept the sound and dropped the cover (measured on a
  /// real server: 48 audio tracks with covers, 2 "best" ones without).
  Quality applyRule(String url) {
    if (this == Quality.audio) return this;
    if (MediaPlatform.detect(url).isAudioOnly) return Quality.audio;
    return this;
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
