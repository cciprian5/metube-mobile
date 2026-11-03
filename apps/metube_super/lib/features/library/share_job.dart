import 'dart:io';

/// How long a shared copy stays. The share menu returns before the
/// receiving app has finished reading the file, so deleting it at once
/// broke the share in apps that read it late.
const shareKeep = Duration(hours: 1);

enum SharePhase { pulling, ready, failed }

/// The share in flight, as the sheet shows it.
class ShareJob {
  const ShareJob({
    required this.url,
    required this.title,
    this.received = 0,
    this.total = 0,
    this.rate,
    this.phase = SharePhase.pulling,
    this.error,
  });

  final String url;
  final String title;
  final int received;

  /// Zero until the server says, unless the library already knew the size.
  final int total;

  /// Bytes a second, smoothed; null until there is enough to measure.
  final double? rate;
  final SharePhase phase;
  final Object? error;

  double? get progress =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;

  ShareJob copyWith({
    int? received,
    int? total,
    double? rate,
    SharePhase? phase,
    Object? error,
  }) => ShareJob(
    url: url,
    title: title,
    received: received ?? this.received,
    total: total ?? this.total,
    rate: rate ?? this.rate,
    phase: phase ?? this.phase,
    error: error ?? this.error,
  );
}

/// A smoothed speed. A raw reading per callback jumps around too much to
/// read, so each sample a half second apart moves it a third of the way.
class TransferRate {
  static const _every = Duration(milliseconds: 500);

  Duration? _at;
  int _received = 0;
  double? value;

  double? sample(int received, Duration at) {
    final last = _at;
    if (last == null) {
      _at = at;
      _received = received;
      return value;
    }
    final gap = at - last;
    if (gap < _every) return value;
    final now = (received - _received) * 1000 / gap.inMilliseconds;
    value = value == null ? now : value! + (now - value!) / 3;
    _at = at;
    _received = received;
    return value;
  }
}

/// Deletes copies kept past [shareKeep], and partial files a killed pull
/// left behind. Run at startup and before each share, so the folder never
/// holds more than the last hour's shares.
Future<int> sweepShareFolder(
  String path, {
  Duration olderThan = shareKeep,
}) async {
  final cutoff = DateTime.now().subtract(olderThan);
  var removed = 0;
  try {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        if ((await entity.stat()).modified.isAfter(cutoff)) continue;
        await entity.delete();
        removed++;
      } on FileSystemException {
        // Still open in the receiving app; the next sweep takes it.
      }
    }
  } on FileSystemException {
    // No cache folder to read; nothing to sweep.
  }
  return removed;
}
