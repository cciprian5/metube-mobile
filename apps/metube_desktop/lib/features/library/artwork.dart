import 'dart:io' as io;
import 'dart:math' show max;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart' show Directory, File;
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart' show ImageHeaders;

import '../../data/library_data.dart';

/// Where downloaded covers are kept: `%LOCALAPPDATA%\MeTube Ember\cache\`,
/// a folder that stays on this computer and is not synced with a roaming
/// profile. Overridden in main; null falls back to the package's own
/// cache in the temp folder.
final artworkCacheProvider = Provider<BaseCacheManager?>((ref) => null);

/// The cover cache under [dir]: up to a thousand covers, each kept a month
/// after it was last shown.
BaseCacheManager artworkCacheIn(String dir) => CacheManager(
  Config(
    'covers',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 1000,
    repo: JsonCacheInfoRepository.withFile(io.File('$dir/covers.json')),
    fileSystem: _FolderFileSystem('$dir/covers'),
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
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return Image.file(
    io.File(value),
    fit: BoxFit.cover,
    cacheWidth: decode,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
