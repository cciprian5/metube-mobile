import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/library_data.dart';
import '../../data/lists_data.dart';
import '../../di.dart';

/// What can be done to one clip, as the phone's item actions do it, with
/// this computer's indexes.
class ClipActions {
  ClipActions(this._ref);

  final Ref _ref;

  Future<void> toggleFavorite(String canonicalUrl) async {
    await _ref
        .read(tagsIndexProvider)
        .toggleTag(canonicalUrl, MTConstants.favoritesSystemTag);
    _ref.invalidate(libraryItemsProvider);
  }

  /// The clip on its own site, in the browser.
  Future<void> openOriginal(String canonicalUrl) async {
    final uri = Uri.tryParse(canonicalUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Deletes from the server **by the canonical URL from /history and
  /// nothing else**, then forgets what this computer kept about the clip.
  /// A clip still playing stops once the server has deleted it, not
  /// before: a refusal leaves it playing, and throws for the caller to say.
  Future<void> deleteFromServer(String canonicalUrl) async {
    final api = _ref.read(apiClientProvider);
    if (api == null) return;
    await api.delete([canonicalUrl]);
    final player = _ref.read(playerProvider);
    if (player.state.current?.canonicalUrl == canonicalUrl) {
      await player.stop();
    }
    await _prune(canonicalUrl);
    _ref.invalidate(historyProvider);
  }

  /// The phone's pruning rules: tags, cover, shape, position, offline
  /// entry and list lines go with the clip, so backups do not carry
  /// corpses. **A clip with a copy on this computer stays**, as local-only,
  /// with all of it; the path is checked on disk, not trusted.
  Future<void> _prune(String url) async {
    final offline = _ref.read(offlineIndexProvider);
    final path = (await offline.readAll())[url];
    if (path != null && path.isNotEmpty && await File(path).exists()) return;
    await _ref.read(artworkIndexProvider).removeKeysAndFiles([url]);
    await _ref.read(keptCoverIndexProvider).removeKeysAndFiles([url]);
    await _ref.read(tagsIndexProvider).removeKey(url);
    await _ref.read(mediaShapeIndexProvider).removeKey(url);
    await PlaybackPositionStore(
      store: _ref.read(keyValueStoreProvider),
      mutex: _ref.read(prefsMutexProvider),
    ).clear(url);
    await offline.removeKey(url);
    // And the saved lists, or the dead line stays and is skipped as broken
    // each time the list plays.
    await _ref.read(playlistsStoreProvider).removeFromAll([url]);
    _ref.invalidate(playlistsProvider);
  }
}

final clipActionsProvider = Provider((ref) => ClipActions(ref));
