import 'dart:io' as io;
import 'dart:math' show max;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart' show Directory, File;
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart' show ImageHeaders, youtubeWideCover;
import 'package:mt_ui/mt_ui.dart' show MTMotion, mtMotionDuration;

import '../../data/library_data.dart';

/// Where downloaded covers are kept: `%LOCALAPPDATA%\MeTube Ember\cache\`,
/// a folder that stays on this computer and is not synced with a roaming
/// profile. Overridden in main; null falls back to the package's own
/// cache in the temp folder.
final artworkCacheProvider = Provider<BaseCacheManager?>((ref) => null);

/// The cover cache under [dir]: up to a thousand covers, each kept a month
/// after it was last shown. A cover worth keeping for good is copied out
/// of it (see CoverKeeper), since the cache forgets and deletes. Tests
/// pass their own [fileService].
BaseCacheManager artworkCacheIn(String dir, {FileService? fileService}) =>
    CacheManager(
      Config(
        'covers',
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 1000,
        repo: JsonCacheInfoRepository.withFile(io.File('$dir/covers.json')),
        fileSystem: _FolderFileSystem('$dir/covers'),
        fileService: fileService ?? HttpFileService(),
      ),
    );

class _FolderFileSystem implements FileSystem {
  _FolderFileSystem(String path)
    : _dir = const LocalFileSystem().directory(path);

  final Directory _dir;

  @override
  Future<File> createFile(String name) async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
    return _dir.childFile(name);
  }
}

/// **The cover of the clip at [url] as a file on this computer**, for
/// Windows' media flyout: [artwork] or else the library's cover for it; a
/// path as it is, an address from the cover cache, fetched into it with
/// the server's headers when it is the server's own (they go to the server
/// alone, as for the cards). Null when there is none.
Future<String?> coverFileOf(WidgetRef ref, String url, String? artwork) async {
  final library = ref.read(libraryItemsProvider).valueOrNull ?? const [];
  final picture =
      artwork ??
      library.where((i) => i.canonicalUrl == url).firstOrNull?.thumbnail;
  if (picture == null || picture.isEmpty) return null;
  return _coverFile(ref, picture);
}

Future<String?> _coverFile(WidgetRef ref, String artwork) async {
  if (!artwork.startsWith('http')) {
    return io.File(artwork).existsSync() ? artwork : null;
  }
  final cache = ref.read(artworkCacheProvider) ?? DefaultCacheManager();
  final file = await cache.getSingleFile(
    artwork,
    headers: ref.read(apiClientProvider)?.imageHeadersFor(artwork) ?? const {},
  );
  return file.path;
}

/// A clip's cover, or null when it has none, so the card draws its own
/// placeholder instead of an empty box.
///
/// A YouTube cover is the clip's official image from YouTube, whose
/// address the history already carries. **It goes without the server's
/// password**: `imageHeadersFor` sends credentials to the server's own
/// address alone, never to an image host. A local file (a cover the phone
/// app generated and shared through a backup) is drawn from disk.
///
/// [width] and [height] are the box in logical pixels; the image is
/// decoded at that size, so a 1280x720 cover in a small card does not hold
/// megabytes of memory.
Widget? artworkFor(
  WidgetRef ref,
  BuildContext context,
  String? value, {
  required double width,
  double? height,
}) {
  if (value == null || value.isEmpty) return null;
  final ratio = MediaQuery.devicePixelRatioOf(context);
  final decode = (max(width, (height ?? 0) * 16 / 9) * ratio).round();
  if (value.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: value,
      httpHeaders: ref.read(apiClientProvider)?.imageHeadersFor(value),
      cacheManager: ref.read(artworkCacheProvider),
      fit: BoxFit.cover,
      memCacheWidth: decode,
      // At the app's own pace, not the package's half-second in and full
      // second out.
      fadeInDuration: mtMotionDuration(context, MTMotion.reveal),
      fadeOutDuration: mtMotionDuration(context, MTMotion.fast),
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return Image.file(
    io.File(value),
    fit: BoxFit.cover,
    cacheWidth: decode,
    // A cover kept on disk fades in as one from the network does, rather
    // than appearing in a frame; one already decoded shows at once.
    frameBuilder: (context, child, frame, sync) => sync
        ? child
        : AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: mtMotionDuration(context, MTMotion.reveal),
            curve: MTMotion.entrance,
            child: child,
          ),
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

/// A square cover (the player bar's), which wants a wider picture than a
/// card.
///
/// YouTube's `hqdefault` is 4:3 with the 16:9 picture between black bands:
/// a card's 16:9 box crops them away, a square one shows them. So a YouTube
/// cover asks for the wide thumbnail, which has none, and where an upload
/// has no wide one the 4:3 picture is enlarged by 4/3 so the bands fall
/// outside the square. A cover kept on this computer takes the wide one
/// from [canonicalUrl]. Anything else is drawn as [artworkFor] draws it.
Widget? squareArtworkFor(
  WidgetRef ref,
  BuildContext context,
  String? value, {
  required String? canonicalUrl,
  required double side,
}) {
  final wide = youtubeWideCover(value, canonicalUrl);
  final plain = artworkFor(ref, context, value, width: side, height: side);
  if (wide == null) return plain;
  return CachedNetworkImage(
    imageUrl: wide,
    cacheManager: ref.read(artworkCacheProvider),
    // The whole square, not the picture's own 16:9 inside it.
    width: side,
    height: side,
    fit: BoxFit.cover,
    memCacheWidth: (side * 16 / 9 * MediaQuery.devicePixelRatioOf(context))
        .round(),
    fadeInDuration: mtMotionDuration(context, MTMotion.reveal),
    fadeOutDuration: mtMotionDuration(context, MTMotion.fast),
    errorWidget: (_, _, _) => Transform.scale(
      scale: 4 / 3,
      child: SizedBox.square(
        dimension: side,
        child: plain ?? const SizedBox.shrink(),
      ),
    ),
  );
}
