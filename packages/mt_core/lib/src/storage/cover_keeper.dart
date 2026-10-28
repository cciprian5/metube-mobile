import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'artwork_index.dart';
import 'probe_failure_index.dart';

/// What asking the web for a cover came to.
final class FetchedCover {
  const FetchedCover.found(Uint8List this.bytes) : gone = false;

  /// The host answered that the picture is no more (404 or 410): the
  /// clip was taken down at its source.
  const FetchedCover.gone() : bytes = null, gone = true;

  /// No answer worth acting on (offline, a timeout, a server error): try
  /// again another time.
  const FetchedCover.failed() : bytes = null, gone = false;

  final Uint8List? bytes;
  final bool gone;
}

/// Fetches a cover from its address. The app supplies it, so the network
/// stays in the app's own image cache and the server's password goes to
/// the server alone.
typedef CoverFetcher = Future<FetchedCover> Function(String url);

/// A picture taken from the clip's own file, for a cover gone at its
/// source; null when there is none.
typedef CoverFallback = Future<Uint8List?> Function(String canonicalUrl);

/// What keeping one cover came to.
enum CoverOutcome {
  /// The online cover is now a file on this device.
  kept,

  /// The online cover was gone; a picture from the clip's file took its
  /// place.
  replaced,

  /// Gone, and the clip's file gave nothing either: left alone for a day.
  gone,

  /// Nothing could be asked: try again later.
  failed,
}

/// **Keeps a clip's online cover as a file on this device**, so a clip
/// taken down at its source (YouTube deletes the picture with the video)
/// keeps the face it had in the library. Its file sits in the
/// [KeptCoverIndex] under the clip's canonical URL, which the library
/// prefers to the online address, and which deleting the clip removes with
/// it.
///
/// A cover already gone is replaced by a picture from the clip's own file
/// ([fallback]), the way clips with no online cover get theirs.
final class CoverKeeper {
  CoverKeeper({
    required this.kept,
    required this.failures,
    required this.folder,
    required this.fetch,
    this.fallback,
    Future<Uint8List> Function(Uint8List picture)? shrink,
    DateTime Function()? now,
  }) : _shrink = shrink ?? _asIs,
       _now = now ?? DateTime.now;

  final KeptCoverIndex kept;
  final ProbeFailureIndex failures;

  /// Where the files are written: a folder of the app's own.
  final Directory folder;
  final CoverFetcher fetch;
  final CoverFallback? fallback;
  final Future<Uint8List> Function(Uint8List picture) _shrink;
  final DateTime Function() _now;

  static Future<Uint8List> _asIs(Uint8List picture) async => picture;

  /// The clips, of [covers] (canonical URL to the cover's address), whose
  /// online cover is not kept yet, in the order given.
  Future<List<String>> candidates(Map<String, String?> covers) async {
    final known = await kept.readAll();
    final failed = await failures.readAll();
    final now = _now();
    return [
      for (final MapEntry(key: url, value: cover) in covers.entries)
        if (cover != null &&
            cover.startsWith('http') &&
            !_isFile(known[url]) &&
            !failures.isCoolingDown(failed, url, now: now))
          url,
    ];
  }

  /// Whether [kept] is a picture on this device. A path whose file is
  /// missing (cleared by hand, or written on another device) does not
  /// count, so the cover is kept again.
  static bool _isFile(String? kept) =>
      kept != null && !kept.startsWith('http') && File(kept).existsSync();

  /// Keeps the cover at [cover] for the clip at [canonicalUrl].
  Future<CoverOutcome> keep(String canonicalUrl, String cover) async {
    final FetchedCover answer;
    try {
      answer = await fetch(cover);
    } on Object {
      return CoverOutcome.failed;
    }
    if (answer.bytes case final bytes? when bytes.isNotEmpty) {
      return await _write(canonicalUrl, bytes)
          ? CoverOutcome.kept
          : CoverOutcome.failed;
    }
    if (!answer.gone) return CoverOutcome.failed;
    Uint8List? picture;
    try {
      picture = await fallback?.call(canonicalUrl);
    } on Object {
      picture = null;
    }
    if (picture != null &&
        picture.isNotEmpty &&
        await _write(canonicalUrl, picture)) {
      return CoverOutcome.replaced;
    }
    await failures.put(canonicalUrl, _now());
    return CoverOutcome.gone;
  }

  /// One round over [covers] (canonical URL to the cover's address), one
  /// clip at a time so nothing else waits: what was kept and what was
  /// replaced. It rests after [restAfter] failures in a row, the network
  /// most likely gone, and stops when [stopped] says so.
  Future<({int kept, int replaced})> keepAll(
    Map<String, String?> covers, {
    bool Function()? stopped,
    int restAfter = 6,
  }) async {
    var kept = 0;
    var replaced = 0;
    var failedInRow = 0;
    for (final url in await candidates(covers)) {
      if (stopped?.call() ?? false) break;
      switch (await keep(url, covers[url]!)) {
        case CoverOutcome.kept:
          kept++;
          failedInRow = 0;
        case CoverOutcome.replaced:
          replaced++;
          failedInRow = 0;
        case CoverOutcome.gone:
          failedInRow = 0;
        case CoverOutcome.failed:
          if (++failedInRow >= restAfter) {
            return (kept: kept, replaced: replaced);
          }
      }
    }
    return (kept: kept, replaced: replaced);
  }

  Future<bool> _write(String canonicalUrl, Uint8List picture) async {
    final small = await _shrink(picture);
    // Checked again just before writing: a file may have been kept from
    // elsewhere while this one was being fetched.
    if (_isFile(await kept.artworkOf(canonicalUrl))) return false;
    await folder.create(recursive: true);
    final file = File('${folder.path}/${fileNameFor(canonicalUrl, small)}');
    await file.writeAsBytes(small, flush: true);
    await kept.put(canonicalUrl, file.path);
    return true;
  }

  /// A stable name from the canonical URL, which holds characters no file
  /// system accepts: 64-bit FNV-1a, with the picture's own extension.
  static String fileNameFor(String canonicalUrl, Uint8List picture) {
    var hash = (0xcbf29ce4 << 32) | 0x84222325;
    for (final byte in utf8.encode(canonicalUrl)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    String half(int v) => v.toRadixString(16).padLeft(8, '0');
    final png =
        picture.length > 4 &&
        picture[0] == 0x89 &&
        picture[1] == 0x50 &&
        picture[2] == 0x4E &&
        picture[3] == 0x47;
    return '${half(hash >>> 32)}${half(hash & 0xFFFFFFFF)}'
        '.${png ? 'png' : 'jpg'}';
  }
}
