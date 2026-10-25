import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_ui/mt_ui.dart';

import '../../data/clip_handover.dart';
import '../../data/library_data.dart';
import 'artwork.dart';
import 'item_menu.dart';

/// One library item in the current layout: a grid card, a table row, or a
/// compact row. The shared Wahaj pieces draw it; this only says what to
/// show.
class LibraryItemView extends ConsumerWidget {
  const LibraryItemView({
    super.key,
    required this.item,
    required this.mode,
    required this.columns,
    required this.playing,
    required this.paused,
    required this.onPlay,
  });

  final LibraryItem item;
  final LibraryViewMode mode;

  /// Set for a row of the table.
  final MTMediaColumns? columns;

  /// This is the clip in the player; [paused] says it is not running.
  final bool playing;
  final bool paused;
  final VoidCallback onPlay;

  /// The cover boxes of the grid and the compact row (`MTLibrarySliver`
  /// and `MTMediaCard`), for decoding at the size actually drawn.
  static const double _gridCell = 210;
  static const double _compactWidth = 64;

  /// A right click opens the clip's menu; a drag carries its file out of
  /// the window.
  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onSecondaryTapUp: (d) =>
        unawaited(showItemMenu(context, ref, d.globalPosition, item)),
    child: ref.watch(clipDragProvider)(item, _view(context, ref)),
  );

  Widget _view(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final subtitle = mtMetaLine([
      item.uploader,
      if (item.timestamp != null && columns?.added != true)
        mtTimeAgo(context, item.timestamp!),
    ]);
    final locationLabel = switch (item.location) {
      MTMediaLocation.offline || MTMediaLocation.both => l.availabilityOffline,
      MTMediaLocation.onServer => l.filterServer,
      MTMediaLocation.none => null,
    };
    final platform = platformKindOf(item.platform);
    final duration = item.duration == null
        ? null
        : mtFormatDuration(item.duration!);

    Future<void> toggleFavorite() async {
      await ref
          .read(tagsIndexProvider)
          .toggleTag(item.canonicalUrl, MTConstants.favoritesSystemTag);
      ref.invalidate(libraryItemsProvider);
    }

    void favorite() => unawaited(toggleFavorite());

    Widget? cover(double width, double height) =>
        artworkFor(ref, context, item.thumbnail, width: width, height: height);

    if (columns case final columns?) {
      return MTMediaRow(
        columns: columns,
        title: item.title,
        subtitle: subtitle,
        thumbnail: cover(MTMediaColumns.thumbWidth, MTMediaColumns.thumbHeight),
        platform: platform,
        duration: duration,
        size: item.sizeBytes == null ? null : mtFormatSize(item.sizeBytes!),
        added: item.timestamp == null
            ? null
            : mtTimeAgo(context, item.timestamp!),
        tags: item.tags,
        location: item.location,
        locationLabel: locationLabel,
        favorite: item.favorite,
        audio: item.isAudio,
        highlighted: playing,
        onFavoriteToggle: favorite,
        onTap: onPlay,
      );
    }
    if (mode == LibraryViewMode.grid) {
      return MTMediaGridCard(
        title: item.title,
        subtitle: subtitle,
        // The grid's widest cell, so a cover is never decoded too small.
        thumbnail: cover(_gridCell, _gridCell * 9 / 16),
        platform: platform,
        location: item.location,
        locationLabel: locationLabel,
        duration: duration,
        favorite: item.favorite,
        audio: item.isAudio,
        playing: playing,
        paused: paused,
        onFavoriteToggle: favorite,
        onTap: onPlay,
      );
    }
    return MTMediaCard(
      compact: true,
      title: item.title,
      subtitle: subtitle,
      thumbnail: cover(_compactWidth, _compactWidth * 10 / 16),
      platform: platform,
      location: item.location,
      locationLabel: locationLabel,
      duration: duration,
      favorite: item.favorite,
      audio: item.isAudio,
      playing: playing,
      paused: paused,
      onFavoriteToggle: favorite,
      onTap: onPlay,
    );
  }
}
