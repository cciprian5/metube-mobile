import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../data/library_data.dart';
import '../features/clip/clip_actions.dart';
import '../features/library/artwork.dart';
import 'player_controls.dart';
import 'shell_metrics.dart';

/// The player bar's start: the clip's cover, what plays and its channel,
/// and its heart. A click opens the clip's page, the way back to its
/// picture from anywhere.
class EmberNowPlaying extends ConsumerWidget {
  const EmberNowPlaying({super.key, required this.state, required this.onOpen});

  final MTPlayerState state;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final text = Theme.of(context).textTheme;
    final item = state.current;
    final side = EmberShellSize.playerBar - MTSpace.xxl;
    // The library's entry, for the cover found later and the heart.
    final entry = item == null
        ? null
        : (ref.watch(libraryItemsProvider).valueOrNull ?? const [])
              .where((i) => i.canonicalUrl == item.canonicalUrl)
              .firstOrNull;
    final cover = entry?.thumbnail ?? item?.artworkUrl;
    final art = squareArtworkFor(
      ref,
      context,
      cover,
      canonicalUrl: item?.canonicalUrl,
      side: side,
    );
    final details = Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(MTCorners.desktop.thumb),
          child: Container(
            width: side,
            height: side,
            color: p.cardAlt,
            alignment: Alignment.center,
            child:
                art ??
                MTIcon(MTIcons.headphones, size: MTSpace.xl, color: p.ink3),
          ),
        ),
        const SizedBox(width: MTSpace.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item?.title ?? l.desktopNothingPlaying,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // A title keeps its own direction, so an English one cut
                // short in an Arabic window loses its end, not its start.
                textDirection: item == null
                    ? null
                    : mtTextDirectionOf(item.title, Directionality.of(context)),
                style: text.titleSmall?.copyWith(
                  color: item == null ? p.ink3 : p.ink,
                ),
              ),
              if (item?.uploader case final who?)
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: p.ink3),
                ),
            ],
          ),
        ),
      ],
    );
    if (item == null) return details;
    final favorite = entry?.favorite ?? false;
    return Row(
      children: [
        Expanded(
          // A button to a screen reader too: it opens the clip's page.
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: () => onOpen(item.canonicalUrl),
              borderRadius: BorderRadius.circular(MTCorners.desktop.thumb),
              child: details,
            ),
          ),
        ),
        // Only for what the library holds: a heart needs an entry to keep.
        if (entry != null)
          EmberPlayerControl(
            icon: favorite ? MTIcons.favoriteOn : MTIcons.favorite,
            label: favorite ? l.removeFromFavorites : l.addToFavorites,
            selected: favorite,
            color: p.favorite,
            onTap: () => unawaited(
              ref.read(clipActionsProvider).toggleFavorite(item.canonicalUrl),
            ),
          ),
      ],
    );
  }
}
