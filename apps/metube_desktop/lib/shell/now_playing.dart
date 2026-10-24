import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'shell_metrics.dart';

/// The player bar's start: what plays, and its channel. A click opens the
/// clip's page, the way back to its picture from anywhere.
class EmberNowPlaying extends StatelessWidget {
  const EmberNowPlaying({super.key, required this.state, required this.onOpen});

  final MTPlayerState state;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final item = state.current;
    final side = EmberShellSize.playerBar - MTSpace.xxl;
    final row = Row(
      children: [
        Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: p.cardAlt,
            borderRadius: BorderRadius.circular(MTCorners.desktop.thumb),
          ),
          alignment: Alignment.center,
          child: MTIcon(MTIcons.headphones, size: MTSpace.xl, color: p.ink3),
        ),
        const SizedBox(width: MTSpace.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item?.title ?? context.mtl.desktopNothingPlaying,
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
    if (item == null) return row;
    return InkWell(
      onTap: () => onOpen(item.canonicalUrl),
      borderRadius: BorderRadius.circular(MTCorners.desktop.thumb),
      child: row,
    );
  }
}
