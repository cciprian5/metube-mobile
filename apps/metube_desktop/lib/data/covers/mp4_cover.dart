import 'dart:typed_data';

/// Reads [length] bytes from [start] of a file (an HTTP range on the
/// server); fewer come back at the end of the file.
typedef RangeReader = Future<Uint8List> Function(int start, int length);

/// The cover picture embedded in an MP4 or M4A file, found by reading
/// **only the boxes that hold it**, never the whole file.
///
/// Where it lives: `moov` > `udta` > `meta` > `ilst` > `covr` > `data`, the
/// iTunes layout yt-dlp writes when it embeds a thumbnail. Measured on the
/// owner's server: every audio download carries one, near the start of
/// the file, so a quarter of a megabyte is read for each.
///
/// The `moov` box sits at the start of a file written for streaming, or
/// after the media at its end; the top-level boxes are walked by their
/// sizes, one small read each, until it is found.
abstract final class Mp4Cover {
  /// The first read: enough for the start of a streaming file whole.
  static const firstRead = 256 * 1024;

  /// A `moov` box larger than this is not read: covers are small, and a
  /// broken size must not ask the server for gigabytes.
  static const maxMoov = 16 * 1024 * 1024;

  /// The picture's bytes (JPEG or PNG), or null when the file has none.
  static Future<Uint8List?> find(RangeReader read) async {
    final head = await read(0, firstRead);
    var offset = 0;
    // A real file has a handful of top-level boxes; the cap stops a loop
    // over a damaged one.
    for (var step = 0; step < 32; step++) {
      final header = offset + 16 <= head.length
          ? Uint8List.sublistView(head, offset, offset + 16)
          : await read(offset, 16);
      if (header.length < 8) return null;
      final box = _Box.at(header, 0);
      if (box == null) return null;
      if (box.type == 'moov') {
        if (box.size > maxMoov) return null;
        final moov = offset + box.size <= head.length
            ? Uint8List.sublistView(head, offset, offset + box.size)
            : await read(offset, box.size);
        return _inMoov(moov, box.headerLength);
      }
      if (box.size == 0) return null; // runs to the end: nothing after it
      offset += box.size;
    }
    return null;
  }

  static Uint8List? _inMoov(Uint8List moov, int start) {
    final udta = _child(moov, start, moov.length, 'udta');
    if (udta == null) return null;
    final meta = _child(moov, udta.$1, udta.$2, 'meta');
    if (meta == null) return null;
    // `meta` is a full box (four bytes of version and flags first) in the
    // iTunes layout, and a plain one in QuickTime's; both are tried.
    final ilst =
        _child(moov, meta.$1 + 4, meta.$2, 'ilst') ??
        _child(moov, meta.$1, meta.$2, 'ilst');
    if (ilst == null) return null;
    final covr = _child(moov, ilst.$1, ilst.$2, 'covr');
    if (covr == null) return null;
    final data = _child(moov, covr.$1, covr.$2, 'data');
    // The data box: a type (13 JPEG, 14 PNG) and a locale, then the picture.
    if (data == null || data.$2 - data.$1 <= 8) return null;
    return Uint8List.sublistView(moov, data.$1 + 8, data.$2);
  }

  /// The content range (start, end) of the first [type] box between
  /// [from] and [to].
  static (int, int)? _child(Uint8List bytes, int from, int to, String type) {
    var offset = from;
    while (offset + 8 <= to) {
      final box = _Box.at(bytes, offset);
      if (box == null || box.size == 0 || offset + box.size > to) return null;
      if (box.type == type) {
        return (offset + box.headerLength, offset + box.size);
      }
      offset += box.size;
    }
    return null;
  }
}

class _Box {
  const _Box(this.size, this.type, this.headerLength);

  final int size;
  final String type;
  final int headerLength;

  static _Box? at(Uint8List b, int o) {
    if (o + 8 > b.length) return null;
    final data = ByteData.sublistView(b);
    var size = data.getUint32(o);
    final type = String.fromCharCodes(b, o + 4, o + 8);
    var header = 8;
    if (size == 1) {
      // A 64-bit size follows the type.
      if (o + 16 > b.length) return null;
      size = data.getUint64(o + 8);
      header = 16;
    } else if (size != 0 && size < 8) {
      return null;
    }
    return _Box(size, type, header);
  }
}
