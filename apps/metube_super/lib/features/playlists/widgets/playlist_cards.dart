import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// A manual playlist card: a mosaic cover of up to four thumbnails, plus a
/// play button and a pin badge.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onPlay,
    required this.onLongPress,
    this.thumbnails = const [],
  });

  final SavedPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onLongPress;

  /// Up to four covers from the playlist's items; it may be empty.
  final List<Widget> thumbnails;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l10n = context.mtl;

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(MTRadius.cardLg),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(MTRadius.cardLg),
        child: Container(
          padding: const EdgeInsets.all(MTSpace.xs + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.cardLg),
            border: Border.all(
              color: playlist.pinned ? p.accent.withValues(alpha: 0.4) : p.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The cover fills whatever is left of the card, so no dead
              // space remains.
              Expanded(
                child: _Cover(
                  thumbnails: thumbnails,
                  pinned: playlist.pinned,
                  pinnedLabel: l10n.pinPlaylist,
                  onPlay: onPlay,
                ),
              ),
              const SizedBox(height: MTSpace.xs + 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium!.copyWith(fontSize: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                child: Text(
                  [
                    l10n.queueItemsCount(playlist.items.length),
                    if (playlist.lastPlayedAt != null)
                      mtTimeAgo(context, playlist.lastPlayedAt!),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall!.copyWith(color: p.ink3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.thumbnails,
    required this.pinned,
    required this.pinnedLabel,
    required this.onPlay,
  });

  final List<Widget> thumbnails;
  final bool pinned;
  final String pinnedLabel;
  final VoidCallback onPlay;

  /// **A mosaic that adapts to the count** (requested 2026-09-08): it was
  /// always two cells, so a playlist of twenty items was represented by two
  /// covers. Now it goes up to four, and the progression is deliberate:
  /// **three means one large and two small** rather than a grid with an
  /// empty quarter, and one fills the whole cover instead of half of it
  /// sitting dead.
  ///
  /// **And `stretch` is mandatory in every row and column** (device check
  /// 2026-09-05): without it the cell receives no tight height, so the
  /// image takes its natural height and centres itself, a thin strip in the
  /// middle of an empty card. `BoxFit.cover` does not help, because nothing
  /// is asking it to fill the height.
  Widget _mosaic(BuildContext context, MTPalette p) {
    Widget cell(Widget? child) => ColoredBox(
      color: p.cardAlt,
      child: child ?? Icon(Icons.queue_music_rounded, size: 18, color: p.ink3),
    );
    Widget stretchRow(List<Widget> children) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final child in children) Expanded(child: child)],
    );
    Widget stretchColumn(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final child in children) Expanded(child: child)],
    );

    final t = thumbnails;
    return switch (t.length) {
      0 => cell(null),
      1 => cell(t[0]),
      2 => stretchRow([cell(t[0]), cell(t[1])]),
      3 => stretchRow([
        cell(t[0]),
        stretchColumn([cell(t[1]), cell(t[2])]),
      ]),
      _ => stretchColumn([
        stretchRow([cell(t[0]), cell(t[1])]),
        stretchRow([cell(t[2]), cell(t[3])]),
      ]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(MTRadius.thumb),
          child: _mosaic(context, p),
        ),
        if (pinned)
          PositionedDirectional(
            top: 6,
            start: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MTSpace.xs,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: p.ink.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(MTRadius.badge + 1),
              ),
              child: Text(
                '📌 $pinnedLabel',
                style: Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: p.bg, fontSize: 9),
              ),
            ),
          ),
        PositionedDirectional(
          bottom: 6,
          end: 6,
          child: Material(
            color: p.ink.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(MTRadius.chip),
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(MTRadius.chip),
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.play_arrow_rounded, size: 16, color: p.bg),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
