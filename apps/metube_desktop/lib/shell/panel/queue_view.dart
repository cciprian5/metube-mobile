import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// What comes next, in play order, with the clip playing marked: drag a
/// line by its grip to reorder, click it to play it now.
class QueueView extends StatelessWidget {
  const QueueView({super.key, required this.state, required this.player});

  final MTPlayerState state;
  final MTPlayer player;

  @override
  Widget build(BuildContext context) {
    final ordered = state.ordered;
    final current = state.current;
    final at = current == null ? -1 : ordered.indexOf(current);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ReorderableListView.builder(
            // Material's own handle is a Material icon; the grip below is
            // drawn instead, and only it starts a drag, so a click still
            // plays.
            buildDefaultDragHandles: false,
            itemCount: ordered.length,
            onReorderItem: (from, to) =>
                unawaited(player.moveQueueItem(from, to)),
            itemBuilder: (context, i) => _QueueLine(
              key: ValueKey(Object.hash(ordered[i].canonicalUrl, i)),
              index: i,
              item: ordered[i],
              current: i == at,
              onTap: () => unawaited(
                player.skipToQueueItem(state.items.indexOf(ordered[i])),
              ),
            ),
          ),
        ),
        if (at == ordered.length - 1)
          Padding(
            padding: const EdgeInsets.only(top: MTSpace.sm),
            child: Text(
              context.mtl.desktopQueueEnd,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: MTThemeX.of(context).palette.ink3),
            ),
          ),
      ],
    );
  }
}

class _QueueLine extends StatelessWidget {
  const _QueueLine({
    super.key,
    required this.index,
    required this.item,
    required this.current,
    required this.onTap,
  });

  final int index;
  final PlaylistItem item;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l = context.mtl;
    return Material(
      color: current ? p.accentSoft : p.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTCorners.desktop.chip),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // A floor, not a fixed height: with large text the two lines need
        // more than one row's worth.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MTDensity.desktop.row + MTSpace.sm,
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Tooltip(
                    message: l.desktopDragToReorder,
                    child: SizedBox(
                      width: MTSpace.xxl,
                      height: MTDensity.desktop.row,
                      child: CustomPaint(painter: _Grip(p.ink3)),
                    ),
                  ),
                ),
              ),
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
                        color: current ? p.accentInk : p.ink,
                        fontWeight: current ? FontWeight.w700 : null,
                      ),
                    ),
                    if (item.uploader case final who?)
                      Text(
                        who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(color: p.ink3),
                      ),
                  ],
                ),
              ),
              if (item.duration case final length?)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: MTSpace.xs,
                    end: MTSpace.sm,
                  ),
                  child: Text(
                    mtFormatDuration(length),
                    style: text.labelSmall?.tabular.copyWith(color: p.ink3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six small dots, the grip a line is dragged by.
class _Grip extends CustomPainter {
  const _Grip(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final c = size.center(Offset.zero);
    const gap = MTSpace.xxs;
    for (final dx in [-gap / 2, gap / 2]) {
      for (final dy in [-gap, 0.0, gap]) {
        canvas.drawCircle(c + Offset(dx, dy), gap / 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Grip old) => old.color != color;
}
