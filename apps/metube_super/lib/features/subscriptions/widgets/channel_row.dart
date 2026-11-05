import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../library/artwork_view.dart';
import '../channel_actions.dart';

/// One followed channel, as the Windows app draws it: the covers of its
/// last three clips here, its name, what the library holds from it, and
/// the switch that pauses it. A failed last check reads in red under the
/// name. A tap opens the channel's page, where its other actions are.
///
/// [stats] is null when no clip here matches the channel: the row then
/// shows the server's facts alone, never a count it cannot know.
class ChannelRow extends ConsumerWidget {
  const ChannelRow({
    super.key,
    required this.sub,
    required this.stats,
    required this.onOpen,
  });

  final ChannelSubscription sub;
  final ChannelStats? stats;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final meta = switch (stats) {
      final s? => mtMetaLine([
        l10n.desktopInLibrary(s.count),
        if (s.unwatched > 0) l10n.desktopNotWatched(s.unwatched),
        if (s.lastArrival case final at?)
          l10n.desktopLastArrival(mtTimeAgo(context, at)),
      ]),
      null => channelServerLine(context, sub),
    };
    final faded = sub.enabled ? 1.0 : 0.55;
    return InkWell(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MTSpace.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: p.line,
              width: MTThemeX.of(context).hairline,
            ),
          ),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: faded,
              child: ChannelCovers(
                name: sub.name,
                covers: stats?.covers ?? const [],
              ),
            ),
            const SizedBox(width: MTSpace.md),
            Expanded(
              flex: 3,
              child: Opacity(
                opacity: faded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: mtTextDirectionOf(
                        sub.name,
                        Directionality.of(context),
                      ),
                      style: text.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: MTSpace.xxs),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall,
                    ),
                    if (sub.error case final why? when why.isNotEmpty)
                      Text(
                        why,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: text.labelSmall!.copyWith(color: p.err),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MTSpace.sm),
            // "Paused" is said beside the switch; the usual state is not.
            if (!sub.enabled)
              // It gives way before the name does on the narrowest phones.
              Flexible(
                child: Text(
                  l10n.subscriptionPaused,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall,
                ),
              ),
            Switch(
              value: sub.enabled,
              onChanged: (on) => runSubscriptionAction(
                context,
                ref,
                (c) => c.setEnabled(sub, on),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// When the server last looked and how much it has seen, which is what it
/// walked past, not what it downloaded.
String channelServerLine(BuildContext context, ChannelSubscription sub) {
  final l10n = context.mtl;
  return mtMetaLine([
    switch (sub.lastChecked) {
      final at? => l10n.lastCheckedAt(mtTimeAgo(context, at)),
      null => l10n.neverChecked,
    },
    l10n.knownVideos(sub.seenCount),
  ]);
}

/// The last three covers, overlapping, or the channel's initial on a plain
/// tile when the library has none of its clips.
class ChannelCovers extends ConsumerWidget {
  const ChannelCovers({super.key, required this.name, required this.covers});

  final String name;
  final List<String?> covers;

  static const double _width = 52;
  static const double _height = _width * 9 / 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final api = ref.read(apiClientProvider);
    final drawn = [
      for (final c in covers)
        if (c != null && c.isNotEmpty) c,
    ];
    if (drawn.isEmpty) {
      final initial = name.trim().characters.firstOrNull ?? '';
      return Container(
        width: _width + MTSpace.md * 2,
        height: _height + MTSpace.xs,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.cardAlt,
          borderRadius: BorderRadius.circular(MTRadius.thumb),
        ),
        child: Text(
          initial.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium!
              .copyWith(color: p.ink2),
        ),
      );
    }
    const step = MTSpace.md;
    return SizedBox(
      width: _width + step * 2,
      height: _height + MTSpace.xs,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          for (var i = drawn.length - 1; i >= 0; i--)
            PositionedDirectional(
              start: step * i,
              child: MTMediaThumb(
                width: _width,
                height: _height,
                child: artworkFor(
                  drawn[i],
                  headers: api?.imageHeadersFor(drawn[i]),
                  decodeWidth: mtDecodeWidth(context, _width, _height),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
