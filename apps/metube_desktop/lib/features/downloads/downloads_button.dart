import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import 'downloads_panel.dart';

/// The downloads button above the content, with the count of what is
/// under way on its corner; it opens [DownloadsPanel].
class DownloadsButton extends ConsumerWidget {
  const DownloadsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final active = ref.watch(activeDownloadsProvider);
    final label = active > 0
        ? '${l.desktopDownloads} · ${l.activeDownloadsCount(active)}'
        : l.desktopDownloads;
    return MTShortcutTooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MTSpace.xxs / 2),
        child: IconButton(
          onPressed: () => unawaited(showDownloadsPanel(context)),
          // The count beside the arrow's corner, not over the arrow: Material's
          // badge sat on the glyph and hid it.
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              MTIcon(
                MTIcons.download,
                size: MTDensity.desktop.icon,
                color: active > 0 ? p.accentInk : p.ink2,
                semanticLabel: label,
              ),
              if (active > 0)
                PositionedDirectional(
                  top: -MTSpace.xs,
                  end: -MTSpace.sm,
                  child: ExcludeSemantics(child: _Count(active)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small ember pill with the number under way.
class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      constraints: const BoxConstraints(minWidth: MTSpace.lg),
      padding: const EdgeInsets.symmetric(horizontal: MTSpace.xxs),
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: BorderRadius.circular(MTSpace.lg),
        border: Border.all(color: p.bg, width: MTSpace.xxs / 2),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.tabular
            .copyWith(color: p.onAccent, height: 1.3),
      ),
    );
  }
}
