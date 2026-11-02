import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../playlists_providers.dart';

/// The smart playlists as **rows in one quiet group**: an icon, the name,
/// how many it holds, and play. Three dark cards with a glow each were the
/// loudest thing in the tab, for lists the app builds by itself.
class SmartListRows extends StatelessWidget {
  const SmartListRows({super.key, required this.lists, required this.onPlay});

  final List<SmartList> lists;
  final ValueChanged<SmartList> onPlay;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(MTRadius.card),
        border: Border.all(color: p.line, width: MTThemeX.of(context).hairline),
      ),
      child: Column(
        children: [
          for (final (i, list) in lists.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: MTSpace.md),
            InkWell(
              onTap: () => onPlay(list),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MTSpace.md,
                  vertical: MTSpace.sm + 2,
                ),
                child: Row(
                  children: [
                    MTIcon(
                      switch (list.kind) {
                        SmartListKind.favorites => MTIcons.favorite,
                        SmartListKind.latest => MTIcons.clock,
                        SmartListKind.offline => MTIcons.offline,
                      },
                      size: 20,
                      color: p.ink2,
                    ),
                    const SizedBox(width: MTSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (list.kind) {
                              SmartListKind.favorites => l10n.favorites,
                              SmartListKind.latest => l10n.latestAdditions,
                              SmartListKind.offline => l10n.offlineSmartList,
                            },
                            style: text.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            mtMetaLine([
                              l10n.queueItemsCount(list.count),
                              l10n.autoBuilt,
                            ]),
                            style: text.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    MTIcon(MTIcons.playFill, size: 22, color: p.ink2),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
