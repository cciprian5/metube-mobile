import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/channels_data.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/pill.dart';
import '../clip/clip_state.dart';
import '../library/library_item_view.dart';
import 'channel_commands.dart';
import 'channel_match.dart';
import 'channel_row.dart';
import 'follow_dialog.dart';

/// One followed channel: what the server knows of it (when it last
/// looked, how often, at what quality, through which filter, how much it
/// has walked past), its actions, and its clips in the library.
class ChannelPage extends ConsumerWidget {
  const ChannelPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final asked = ref.watch(channelsProvider);
    final state = asked.valueOrNull;
    if (state == null) {
      return Center(
        child: asked.hasError
            ? MTEmptyFrame(
                title: l.failed,
                message: l.errorGeneric(asked.error.toString()),
                actionLabel: l.retry,
                onAction: () => ref.invalidate(channelsProvider),
              )
            : const MTSpinner(),
      );
    }
    final sub = state.byId(id);
    if (sub == null) {
      return Center(
        child: MTEmptyFrame(
          title: l.desktopChannels,
          message: l.subscriptionsEmptyBody,
          actionLabel: l.desktopChannels,
          onAction: () => context.go(EmberRoutes.channels),
        ),
      );
    }
    final match = ref.watch(channelMatchProvider).valueOrNull;
    final stats = match?.stats[sub.id];
    final items = stats?.items ?? const <LibraryItem>[];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            MTSpace.xl,
            MTSpace.sm,
            MTSpace.xl,
            MTSpace.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: _Head(
              sub: sub,
              stats: stats,
              namesChannels: match?.namesChannels ?? true,
            ),
          ),
        ),
        if (items.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              MTSpace.xl,
              0,
              MTSpace.xl,
              MTSpace.xl,
            ),
            sliver: _Clips(items: items),
          ),
      ],
    );
  }
}

class _Head extends ConsumerWidget {
  const _Head({
    required this.sub,
    required this.stats,
    required this.namesChannels,
  });

  final ChannelSubscription sub;
  final ChannelStats? stats;
  final bool namesChannels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final interval = sub.checkIntervalMinutes < 60
        ? l.every30Minutes
        : l.everyHours(sub.checkIntervalMinutes ~/ 60);
    final quality = switch (sub.quality) {
      null => null,
      final wire => switch (Quality.values.where((q) => q.wire == wire)) {
        [Quality.best] => l.qualityBest,
        [Quality.q1080] => l.quality1080,
        [Quality.q720] => l.quality720,
        [Quality.q480] => l.quality480,
        [Quality.audio] => l.audioOnly,
        _ => wire,
      },
    };
    final facts = <(String, String)>[
      (l.checkEvery, interval),
      if (quality != null) (l.subscriptionQuality, quality),
      if (sub.titleRegex case final filter? when filter.isNotEmpty)
        (l.titleFilter, filter),
      if (sub.folder case final folder? when folder.isNotEmpty)
        (l.folder, folder),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                sub.name,
                textDirection: mtTextDirectionOf(
                  sub.name,
                  Directionality.of(context),
                ),
                style: text.headlineSmall,
              ),
            ),
            const SizedBox(width: MTSpace.md),
            ChannelState(enabled: sub.enabled),
          ],
        ),
        const SizedBox(height: MTSpace.xxs),
        Text(
          sub.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: text.bodySmall?.copyWith(color: p.ink3),
        ),
        const SizedBox(height: MTSpace.xxs),
        Text(
          channelServerLine(context, sub),
          style: text.bodySmall?.copyWith(color: p.ink2),
        ),
        if (sub.error case final why? when why.isNotEmpty) ...[
          const SizedBox(height: MTSpace.sm),
          Text(
            why,
            textDirection: TextDirection.ltr,
            style: text.bodySmall?.copyWith(color: p.err),
          ),
        ],
        const SizedBox(height: MTSpace.md),
        Wrap(
          spacing: MTSpace.xl,
          runSpacing: MTSpace.sm,
          children: [
            for (final (label, value) in facts)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: text.labelSmall?.copyWith(color: p.ink3)),
                  Text(value, style: text.bodySmall?.copyWith(color: p.ink)),
                ],
              ),
          ],
        ),
        const SizedBox(height: MTSpace.lg),
        Wrap(
          spacing: MTSpace.sm,
          runSpacing: MTSpace.sm,
          children: [
            EmberPill(
              label: l.checkNow,
              selected: false,
              onTap: () => unawaited(checkChannels(context, ref, only: sub)),
            ),
            EmberPill(
              label: sub.enabled ? l.pauseSubscription : l.resumeSubscription,
              selected: !sub.enabled,
              onTap: () =>
                  unawaited(setChannelEnabled(context, ref, sub, !sub.enabled)),
            ),
            EmberPill(
              label: l.editSubscription,
              selected: false,
              onTap: () => unawaited(showFollowDialog(context, editing: sub)),
            ),
            EmberPill(
              label: l.openChannel,
              icon: MTIcons.external,
              selected: false,
              onTap: () => unawaited(openChannelSite(sub)),
            ),
            EmberPill(
              label: l.unfollow,
              icon: MTIcons.trash,
              selected: false,
              onTap: () => unawaited(_unfollow(context, ref)),
            ),
          ],
        ),
        const SizedBox(height: MTSpace.xl),
        MTSectionHeader(
          title: l.desktopChannelClips,
          trailing: switch (stats) {
            final s? => mtMetaLine([
              l.desktopInLibrary(s.count),
              if (s.unwatched > 0) l.desktopNotWatched(s.unwatched),
            ]),
            null => null,
          },
        ),
        // Said rather than shown as nothing: the server's history may not
        // name channels at all, and then no clip can be matched.
        if (stats == null && !namesChannels) ...[
          const SizedBox(height: MTSpace.sm),
          Text(
            l.desktopNoChannelNames,
            style: text.bodySmall?.copyWith(color: p.ink3),
          ),
        ],
      ],
    );
  }

  Future<void> _unfollow(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    if (await unfollowChannel(context, ref, sub)) {
      router.go(EmberRoutes.channels);
    }
  }
}

/// The channel's clips, as the library's grid draws them.
class _Clips extends ConsumerWidget {
  const _Clips({required this.items});

  final List<LibraryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    return StreamBuilder<MTPlayerState>(
      stream: player.states,
      initialData: player.state,
      builder: (context, snap) {
        final state = snap.data ?? player.state;
        final current = state.current?.canonicalUrl;
        return MTLibrarySliver(
          layout: MTLibraryLayout.grid,
          showLocation: true,
          itemCount: items.length,
          itemBuilder: (context, index, columns) {
            final item = items[index];
            final isCurrent = item.canonicalUrl == current;
            return LibraryItemView(
              item: item,
              mode: LibraryViewMode.grid,
              columns: columns,
              playing: isCurrent,
              paused: isCurrent && !state.playing,
              onPlay: () => unawaited(
                openFromList(ref, GoRouter.of(context), [
                  for (final i in items) toPlaylistItem(i),
                ], index),
              ),
            );
          },
        );
      },
    );
  }
}
