import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'cover_shrink.dart';
import 'mp4_cover.dart';

/// Where a clip's bytes are read from: a range reader on the server's own
/// file, or null when the clip is not there.
typedef ReaderFor = RangeReader? Function(LibraryItem item);

/// A picture the player's engine takes from a clip's own file: a video's
/// frame, or the cover embedded in an audio file; null when none came.
typedef FrameFor = Future<Uint8List?> Function(LibraryItem item);

/// Covers the server never names, kept on this computer: **the picture
/// embedded in an audio file**, read from the server by ranges for M4A and
/// by the engine for the rest, and for a video **a frame of the video
/// itself** ([FrameFor]).
///
/// The phone takes these from Android's media retriever, which Windows does
/// not have. Measured on the owner's server: every audio download (M4A) has
/// one, and reading it costs a quarter of a megabyte and a fifth of a
/// second on the home network, a second or two through the tunnel.
///
/// The rules the phone keeps: a cover already known (YouTube's, or one
/// found before) is never written over; a clip that yields none is noted in
/// [ProbeFailureIndex] and left alone for a day; the server's password goes
/// only to the server, since [ReaderFor] reads nothing else.
class CoverEnricher {
  CoverEnricher({
    required this.artwork,
    required this.failures,
    required this.folder,
    required this.readerFor,
    this.frameFor,
    this.shrink = shrinkCover,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ArtworkIndex artwork;
  final ProbeFailureIndex failures;

  /// Where the pictures are written: the app's own cache folder.
  final Directory folder;
  final ReaderFor readerFor;

  /// null leaves videos alone.
  final FrameFor? frameFor;

  /// Makes a found picture card-sized before it is kept.
  final Future<Uint8List> Function(Uint8List picture) shrink;
  final DateTime Function() _now;

  /// The clips worth asking about, in the order given (the screen's).
  Future<List<LibraryItem>> candidates(List<LibraryItem> items) async {
    final known = await artwork.readAll();
    final failed = await failures.readAll();
    final now = _now();
    return [
      for (final item in items)
        if ((frameFor != null || (item.isAudio && readerFor(item) != null)) &&
            item.thumbnail == null &&
            known[item.canonicalUrl] == null &&
            !failures.isCoolingDown(failed, item.canonicalUrl, now: now))
          item,
    ];
  }

  /// Looks for one clip's cover; true when one was found and kept.
  ///
  /// An MP4 audio file (M4A, MeTube's usual) is read by ranges, the
  /// cheapest way; any other audio (MP3, Opus, FLAC) and every video go
  /// through [frameFor], whose engine shows an audio file's embedded cover
  /// as its one frame.
  Future<bool> enrich(LibraryItem item) async {
    Uint8List? picture;
    final read = item.isAudio && _isMp4(item) ? readerFor(item) : null;
    if (read != null) {
      try {
        picture = await Mp4Cover.find(read);
      } on Object {
        picture = null;
      }
    }
    if (picture == null || picture.isEmpty) {
      final frame = frameFor;
      if (frame == null && read == null) return false;
      try {
        picture = await frame?.call(item);
      } on Object {
        picture = null;
      }
    }
    final url = item.canonicalUrl;
    if (picture == null || picture.isEmpty) {
      await failures.put(url, _now());
      return false;
    }
    picture = await shrink(picture);
    // Checked again just before writing: a cover may have arrived from
    // elsewhere while this one was being read.
    if (await artwork.artworkOf(url) != null) return false;
    await folder.create(recursive: true);
    final file = File('${folder.path}/${_nameFor(url, picture)}');
    await file.writeAsBytes(picture, flush: true);
    await artwork.put(url, file.path);
    return true;
  }

  /// Whether the clip's file is an MP4 container, by its name; a name not
  /// known is tried as one.
  static bool _isMp4(LibraryItem item) {
    final name = (item.serverFilename ?? item.localPath ?? '').toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot < 0) return true;
    return const {
      '.m4a',
      '.mp4',
      '.m4v',
      '.mov',
      '.m4b',
    }.contains(name.substring(dot));
  }

  /// A stable name from the canonical URL, which holds characters no file
  /// system accepts. 64-bit FNV-1a, as the transcripts' file names.
  static String _nameFor(String url, Uint8List picture) {
    var hash = (0xcbf29ce4 << 32) | 0x84222325;
    for (final byte in utf8.encode(url)) {
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
    return '${half(hash >>> 32)}${half(hash & 0xFFFFFFFF)}.${png ? 'png' : 'jpg'}';
  }
}
