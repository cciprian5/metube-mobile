import 'bidi.dart';

/// **A file size as people read it** (field report 2026-09-26: a 3 GB
/// video read "3000 MB").
///
/// Gigabytes from a thousand megabytes up, not from 1024: "1023.9 MB"
/// next to "1.0 GB" is a distinction nobody asked for. One decimal either
/// way.
///
/// **Direction-isolated**, like every figure with a unit: without it an
/// Arabic line reordered "2.2 MB" into "MB 2.2".
String mtFormatSize(int bytes) {
  const megabyte = 1024 * 1024;
  const gigabyte = 1024 * megabyte;
  final text = bytes >= 1000 * megabyte
      ? '${(bytes / gigabyte).toStringAsFixed(1)} GB'
      : '${(bytes / megabyte).toStringAsFixed(1)} MB';
  return mtLtrRun(text);
}

/// **A download speed**, in the same units and isolation as
/// [mtFormatSize]: kilobytes under one megabyte a second, then megabytes.
String mtFormatTransferRate(double bytesPerSecond) {
  const kilobyte = 1024;
  const megabyte = 1024 * kilobyte;
  final text = bytesPerSecond >= megabyte
      ? '${(bytesPerSecond / megabyte).toStringAsFixed(1)} MB/s'
      : '${(bytesPerSecond / kilobyte).round()} KB/s';
  return mtLtrRun(text);
}
