import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mt_core/mt_core.dart' show ArtworkIndex;

/// The widest a kept cover is. A phone video's frame is 1080x1920 or more,
/// and decoding hundreds of those while the library scrolls made it crawl
/// (measured on the owner's library); a card is never wider than this at
/// the largest window and scale.
const coverWidth = 640;

/// [picture] no wider than [coverWidth], as JPEG; unchanged when it is
/// already that small or cannot be read. Off the main isolate: a large
/// frame takes a moment to decode.
Future<Uint8List> shrinkCover(Uint8List picture) async =>
    await Isolate.run<Uint8List?>(() => shrinkCoverNow(picture)) ?? picture;

/// [picture] made smaller on the calling isolate, or null when it needs no
/// change or cannot be read.
Uint8List? shrinkCoverNow(Uint8List picture) {
  final image = img.decodeImage(picture);
  if (image == null || image.width <= coverWidth) return null;
  final small = img.copyResize(
    image,
    width: coverWidth,
    interpolation: img.Interpolation.average,
  );
  return img.encodeJpg(small, quality: 82);
}

/// Shrinks, once, the covers kept before [shrinkCover] existed. A marker
/// file says it is done, so the folder is not read again at every launch.
/// Each file is rewritten in place, so the index keeps pointing at it.
Future<int> shrinkKeptCovers(Directory folder) async {
  final done = File('${folder.path}/.shrunk-$coverWidth');
  if (!folder.existsSync() || done.existsSync()) return 0;
  var shrunk = 0;
  for (final file in folder.listSync().whereType<File>()) {
    if (file.path == done.path) continue;
    try {
      final before = await file.readAsBytes();
      final after = await Isolate.run<Uint8List?>(() => shrinkCoverNow(before));
      if (after == null) continue;
      await file.writeAsBytes(after, flush: true);
      shrunk++;
    } on Object {
      // A file that cannot be read stays as it is; the card falls back.
    }
  }
  await done.writeAsString('');
  return shrunk;
}

/// Whether [picture] is all but black: a video that fades in from black
/// gives such a frame one second in (seen on Instagram reels), and a
/// black card says nothing. Read off a coarse grid, so a large frame
/// costs little.
bool isDarkPicture(Uint8List picture) {
  final image = img.decodeImage(picture);
  if (image == null) return false;
  const steps = 24;
  var sum = 0.0;
  for (var y = 0; y < steps; y++) {
    for (var x = 0; x < steps; x++) {
      final p = image.getPixel(
        x * (image.width - 1) ~/ (steps - 1),
        y * (image.height - 1) ~/ (steps - 1),
      );
      sum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }
  }
  return sum / (steps * steps) < _darkBelow;
}

/// The average brightness, of 255, under which a picture counts as black.
const _darkBelow = 18;

/// Forgets, once, the black covers kept before frames were checked for
/// darkness, deleting their files, so the next search takes them again
/// from further in. A marker file says it is done.
Future<int> forgetDarkCovers(Directory folder, ArtworkIndex artwork) async {
  final done = File('${folder.path}/.dark-checked');
  if (!folder.existsSync() || done.existsSync()) return 0;
  final root = folder.absolute.path.replaceAll(r'\', '/');
  var forgotten = 0;
  final kept = await artwork.readAll();
  for (final MapEntry(key: url, value: path) in kept.entries) {
    if (!path.replaceAll(r'\', '/').startsWith(root)) continue;
    try {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      if (!await Isolate.run(() => isDarkPicture(bytes))) continue;
      await artwork.removeKey(url);
      await file.delete();
      forgotten++;
    } on Object {
      // Left as it is; it costs one black card, not a broken library.
    }
  }
  await done.writeAsString('');
  return forgotten;
}
