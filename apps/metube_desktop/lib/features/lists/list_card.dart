import 'package:flutter/material.dart';

import '../../shell/context_menu.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/shell_metrics.dart';
import '../library/artwork.dart';

/// A list as a card: up to four of its covers, its name and its count.
/// Clicking opens it; the play button over the covers, shown under the
/// pointer, plays it; a right click asks [onMenu].
class ListCard extends ConsumerWidget {
  const ListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.covers,
    required this.onOpen,
    this.onPlay,
    this.onMenu,
    this.pinned = false,
    this.icon = MTIcons.queue,
  });

  final String title;
  final String subtitle;

  /// Cover values (addresses or files) of the first clips, in order.
  final List<String?> covers;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;
  final ValueChanged<Offset>? onMenu;
  final bool pinned;

  /// Drawn when the list has no cover to show.
  final MTIconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l = context.mtl;
    final radius = BorderRadius.circular(MTCorners.desktop.card);
    const width = EmberShellSize.listCard;
    return MenuKey(
      onMenu: onMenu,
      child: SizedBox(
        width: width,
        child: MTHoverLift(
          borderRadius: radius,
          builder: (context, hovered) => Material(
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: pinned ? p.ink3 : p.line,
                width: MTThemeX.of(context).hairline,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              onSecondaryTapUp: onMenu == null
                  ? null
                  : (d) => onMenu!(d.globalPosition),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Mosaic(covers: covers, icon: icon, width: width),
                        if (onPlay != null && hovered)
                          Center(
                            child: MTShortcutTooltip(
                              message: l.playAll,
                              child: Material(
                                color: p.accent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: onPlay,
                                  child: Padding(
                                    padding: const EdgeInsets.all(MTSpace.sm),
                                    child: MTIcon(
                                      MTIcons.playFill,
                                      size: MTSpace.xl,
                                      color: p.onAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(MTSpace.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: mtTextDirectionOf(
                            title,
                            Directionality.of(context),
                          ),
                          style: text.titleSmall?.copyWith(color: p.ink),
                        ),
                        const SizedBox(height: MTSpace.xxs),
                        Text(
                          mtMetaLine([subtitle, if (pinned) l.desktopPinned]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(color: p.ink3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One cover across the box, or four in a square when there are four.
class _Mosaic extends ConsumerWidget {
  const _Mosaic({
    required this.covers,
    required this.icon,
    required this.width,
  });

  final List<String?> covers;
  final MTIconData icon;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final drawn = [
      for (final value in covers)
        if (value != null && value.isNotEmpty) value,
    ];
    Widget cover(String value, double w) =>
        artworkFor(ref, context, value, width: w) ?? const SizedBox.shrink();
    final Widget content;
    if (drawn.length >= 4) {
      final half = width / 2;
      content = Column(
        children: [
          for (final row in [0, 2])
            Expanded(
              child: Row(
                children: [
                  for (final i in [row, row + 1])
                    Expanded(child: cover(drawn[i], half)),
                ],
              ),
            ),
        ],
      );
    } else if (drawn.isNotEmpty) {
      content = cover(drawn.first, width);
    } else {
      content = Center(
        child: MTIcon(icon, size: MTSpace.xxl, color: p.ink3),
      );
    }
    return ColoredBox(color: p.cardAlt, child: content);
  }
}
