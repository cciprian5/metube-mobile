import 'dart:io' show HttpStatus;

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mt_core/mt_core.dart';

/// Fetches an online cover through the cards' own cache: a picture the
/// cache still holds is used as it is, however old (it may be the last
/// copy left); otherwise it is downloaded, with the server's headers only
/// when the address is the server's.
CoverFetcher cachedCoverFetcher(
  BaseCacheManager cache,
  Map<String, String> Function(String url) headersFor,
) => (url) async {
  if (await cache.getFileFromCache(url) case final held?) {
    return FetchedCover.found(await held.file.readAsBytes());
  }
  try {
    final got = await cache.downloadFile(url, authHeaders: headersFor(url));
    return FetchedCover.found(await got.file.readAsBytes());
  } on HttpExceptionWithStatus catch (e) {
    return e.statusCode == HttpStatus.notFound ||
            e.statusCode == HttpStatus.gone
        ? const FetchedCover.gone()
        : const FetchedCover.failed();
  } on Object {
    return const FetchedCover.failed();
  }
};

/// [cachedCoverFetcher] over the cache the cards use when they name none
/// (the phone apps'), so a cover they showed is not fetched twice.
CoverFetcher defaultCoverFetcher(
  Map<String, String> Function(String url) headersFor,
) => cachedCoverFetcher(DefaultCacheManager(), headersFor);
