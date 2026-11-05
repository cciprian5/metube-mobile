import 'dart:async';

import '../../shell/context_menu.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library/artwork.dart';
import 'channel_commands.dart';
import 'channel_match.dart';

/// One followed channel: the covers of its last three clips here, its
/// name, what the library holds from it, its state, and the switch that
/// pauses it. A failed last check marks the row's edge. Clicking opens the
/// channel's page; a right click its menu.
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
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(MTCorners.desktop.card);
    final meta = switch (stats) {
      final s? => mtMetaLine([
        l.desktopInLibrary(s.count),
        if (s.unwatched > 0) l.desktopNotWatched(s.unwatched),
        if (s.lastArrival case final at?)
          l.desktopLastArrival(mtTimeAgo(context, at)),
      ]),
      null => channelServerLine(context, sub),
    };
    return MenuKey(
      onMenu: (at) => unawaited(showChannelMenu(context, ref, sub, at)),
      // **A line under each channel, not a card around it**: seven boxed
      // cards, each with its own border and corners, made a template of a
      // list that only needs to be read down.
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: p.line,
              width: MTThemeX.of(context).hairline,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            onSecondaryTapUp: (d) =>
                unawaited(showChannelMenu(context, ref, sub, d.globalPosition)),
            child: Container(
              decoration: sub.hasError
                  ? BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: p.err, width: MTSpace.xxs),
                      ),
                    )
                  : null,
              padding: const EdgeInsets.all(MTSpace.md),
              child: Row(
                children: [
                  Opacity(
                    opacity: sub.enabled ? 1 : 0.55,
                    child: _Covers(name: sub.name, covers: stats?.covers ?? []),
                  ),
                  const SizedBox(width: MTSpace.md),
                  Expanded(
                    child: Opacity(
                      opacity: sub.enabled ? 1 : 0.55,
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
                            style: text.titleSmall?.copyWith(color: p.ink),
                          ),
                          const SizedBox(height: MTSpace.xxs),
                          Text(
                            meta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(color: p.ink3),
                          ),
                          if (sub.error case final why? when why.isNotEmpty)
                            Text(
                              why,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: text.labelSmall?.copyWith(color: p.err),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: MTSpace.md),
                  ChannelState(enabled: sub.enabled),
                  const SizedBox(width: MTSpace.sm),
                  MTSwitch(
                    value: sub.enabled,
                    semanticLabel: sub.enabled
                        ? l.pauseSubscription
                        : l.resumeSubscription,
                    onChanged: (on) =>
                        unawaited(setChannelEnabled(context, ref, sub, on)),
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

/// When the server last looked and how much it has seen, which is what it
/// walked past, not what it downloaded.
String channelServerLine(BuildContext context, ChannelSubscription sub) {
  final l = context.mtl;
  return mtMetaLine([
    switch (sub.lastChecked) {
      final at? => l.lastCheckedAt(mtTimeAgo(context, at)),
      null => l.neverChecked,
    },
    l.knownVideos(sub.seenCount),
  ]);
}

/// "Paused", in grey words, beside a paused channel's switch; nothing
/// beside an active one. **The usual state is not announced**: an outlined
/// "Active" in the accent on every row said what the switch beside it
/// already said, and coloured the rows that needed no attention.
class ChannelState extends StatelessWidget {
  const ChannelState({super.key, required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (enabled) return const SizedBox.shrink();
    return Text(
      context.mtl.subscriptionPaused,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: MTThemeX.of(context).palette.ink3),
    );
  }
}

/// The last three covers, overlapping, or the channel's initial when the
/// library has none of its clips.
class _Covers extends ConsumerWidget {
  const _Covers({required this.name, required this.covers});

  final String name;
  final List<String?> covers;

  static const double _width = 56;
  static const double _height = _width * 9 / 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final drawn = [
      for (final c in covers)
        if (c != null && c.isNotEmpty) c,
    ];
    if (drawn.isEmpty) {
      final initial = name.trim().characters.firstOrNull ?? '';
      return Container(
        width: _width,
        height: _width,
        alignment: Alignment.center,
        // A plain tile, not a letter in a circle of the accent: that
        // circle on every row is one of the marks of a generated list.
        decoration: BoxDecoration(
          color: p.cardAlt,
          borderRadius: BorderRadius.circular(MTCorners.desktop.thumb),
        ),
        child: Text(
          initial.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: p.ink2),
        ),
      );
    }
    const step = MTSpace.md;
    return SizedBox(
      width: _width + step * (drawn.length - 1),
      height: _width,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          for (var i = drawn.length - 1; i >= 0; i--)
            PositionedDirectional(
              start: step * i,
              child: MTMediaThumb(
                width: _width,
                height: _height,
                child: artworkFor(ref, context, drawn[i], width: _width),
              ),
            ),
        ],
      ),
    );
  }
}
