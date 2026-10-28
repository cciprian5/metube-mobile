import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/grip.dart';
import '../../shell/now_playing_bars.dart';
import '../library/artwork.dart';

/// One clip of a saved list: the grip it is dragged by, its cover, title
/// and length, and a cross to take it out of the list (never off the
/// server). The clip playing is marked; one no longer there says so.
class PlaylistLine extends ConsumerWidget {
  const PlaylistLine({
    super.key,
    required this.index,
    required this.item,
    required this.missing,
    required this.current,
    this.playing = true,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final PlaylistItem item;
  final bool missing;
  final bool current;

  /// The player runs: the current line's bars sway, or stand still.
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  static const double _thumbWidth = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l = context.mtl;
    final subtitle = missing ? l.itemUnavailable : item.uploader;
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.xxs),
      child: Material(
        color: current ? p.accentSoft : p.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MTCorners.desktop.chip),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MTDensity.desktop.row + MTSpace.md,
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: MTShortcutTooltip(
                      message: l.desktopDragToReorder,
                      child: SizedBox(
                        width: MTSpace.xxl,
                        height: MTDensity.desktop.row,
                        child: const EmberGrip(),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: missing ? 0.5 : 1,
                  child: MTMediaThumb(
                    width: _thumbWidth,
                    height: _thumbWidth * 9 / 16,
                    audio: item.isAudio,
                    playing: current,
                    child: artworkFor(
                      ref,
                      context,
                      item.artworkUrl,
                      width: _thumbWidth,
                    ),
                  ),
                ),
                const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: mtTextDirectionOf(
                          item.title,
                          Directionality.of(context),
                        ),
                        style: text.bodySmall?.copyWith(
                          color: missing
                              ? p.ink3
                              : (current ? p.accentInk : p.ink),
                          fontWeight: current ? FontWeight.w700 : null,
                        ),
                      ),
                      if (subtitle case final line?)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: missing ? p.err : p.ink3,
                          ),
                        ),
                    ],
                  ),
                ),
                // At the line's end, after the title, as the phone marks it.
                if (current)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: MTSpace.sm,
                    ),
                    child: NowPlayingBars(playing: playing),
                  ),
                if (item.duration case final length?)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: MTSpace.xs,
                    ),
                    child: Text(
                      mtFormatDuration(length),
                      style: text.labelSmall?.tabular.copyWith(color: p.ink3),
                    ),
                  ),
                MTShortcutTooltip(
                  message: l.desktopRemoveFromList,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: MTIcon(
                      MTIcons.close,
                      size: MTSpace.md,
                      color: p.ink3,
                      semanticLabel: l.desktopRemoveFromList,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
