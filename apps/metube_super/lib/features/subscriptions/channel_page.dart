import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../di.dart';
import '../library/widgets/library_cards.dart';
import '../player/playback_providers.dart';
import 'channel_actions.dart';
import 'channel_match.dart';
import 'subscription_sheet.dart';
import 'subscriptions_providers.dart';
import 'widgets/channel_row.dart';

/// **One followed channel's page**, as in the Windows app: its link, when
/// the server last looked, its actions, how it is set up, and its clips in
/// the library. Opened from its row in the playlists tab or in Settings.
class ChannelPage extends ConsumerWidget {
  const ChannelPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final asked = ref.watch(subscriptionsProvider);
    final sub = asked.valueOrNull?.subscriptions
        ?.where((s) => s.id == id)
        .firstOrNull;
    final match = ref.watch(channelMatchProvider).valueOrNull;
    final stats = sub == null ? null : match?.stats[sub.id];
    final items = stats?.items ?? const <LibraryItem>[];
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (sub != null)
            PopupMenuButton<VoidCallback>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: () => launchUrl(
                    Uri.parse(sub.url),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(l10n.openChannel),
                ),
                PopupMenuItem(
                  value: () => _unfollow(context, ref, sub),
                  child: Text(l10n.unfollow),
                ),
              ],
            ),
        ],
      ),
      body: switch (sub) {
        null when asked.isLoading => const Center(
          child: CircularProgressIndicator(),
        ),
        null => MTEmptyState(
          title: l10n.subscriptionsEmpty,
          message: l10n.subscriptionsEmptyBody,
        ),
        final sub => MTReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MTSpace.pagePad,
              0,
              MTSpace.pagePad,
              140,
            ),
            children: [
              _Head(sub: sub),
              const SizedBox(height: MTSpace.xl),
              MTSectionHeader(
                title: l10n.desktopChannelClips,
                trailing: switch (stats) {
                  final s? => mtMetaLine([
                    l10n.desktopInLibrary(s.count),
                    if (s.unwatched > 0) l10n.desktopNotWatched(s.unwatched),
                  ]),
                  null => null,
                },
              ),
              // The server's history may name no channels at all, and then
              // only a folder of its own matches a channel's clips.
              if (stats == null &&
                  !(match?.namesChannels ?? true) &&
                  (sub.folder?.isEmpty ?? true))
                Padding(
                  padding: const EdgeInsets.only(top: MTSpace.sm),
                  child: Text(
                    l10n.desktopNoChannelNames,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              for (final item in items)
                LibraryItemCard(
                  item: item,
                  onPlay: () => _play(context, ref, items, item),
                ),
            ],
          ),
        ),
      },
    );
  }

  /// A clip plays with the channel's other clips after it, as the library
  /// plays what it shows.
  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    List<LibraryItem> items,
    LibraryItem tapped,
  ) async {
    final queue = [for (final item in items) toPlaylistItem(item)];
    final index = items.indexOf(tapped);
    if (tapped.isAudio) {
      await ref.read(audioHandlerProvider).playItems(queue, startIndex: index);
      return;
    }
    ref.read(playbackRequestProvider.notifier).state = PlaybackRequest(
      items: queue,
      startIndex: index,
    );
    if (context.mounted) {
      context.push(tapped.isShortForm ? '/reels' : '/player');
    }
  }

  Future<void> _unfollow(
    BuildContext context,
    WidgetRef ref,
    ChannelSubscription sub,
  ) async {
    final router = GoRouter.of(context);
    if (await confirmUnfollow(context, ref, sub)) router.pop();
  }
}

class _Head extends ConsumerWidget {
  const _Head({required this.sub});

  final ChannelSubscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final quality = switch (sub.quality) {
      null => null,
      final wire => switch (Quality.values
          .where((q) => q.wire == wire)
          .firstOrNull) {
        Quality.best => l10n.qualityBest,
        Quality.q1080 => l10n.quality1080,
        Quality.q720 => l10n.quality720,
        Quality.q480 => l10n.quality480,
        Quality.audio => l10n.audioOnly,
        null => wire,
      },
    };
    final facts = <(String, String)>[
      (
        l10n.checkEvery,
        sub.checkIntervalMinutes < 60
            ? l10n.every30Minutes
            : l10n.everyHours(sub.checkIntervalMinutes ~/ 60),
      ),
      if (quality != null) (l10n.subscriptionQuality, quality),
      if (sub.folder case final folder? when folder.isNotEmpty)
        (l10n.folder, mtName(folder)),
      if (sub.titleRegex case final filter? when filter.isNotEmpty)
        (l10n.titleFilter, filter),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sub.name,
          textDirection: mtTextDirectionOf(
            sub.name,
            Directionality.of(context),
          ),
          style: text.headlineLarge,
        ),
        const SizedBox(height: MTSpace.xxs),
        Text(
          sub.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: text.bodySmall,
        ),
        Text(channelServerLine(context, sub), style: text.bodySmall),
        if (sub.error case final why? when why.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: MTSpace.xs),
            child: Text(
              why,
              textDirection: TextDirection.ltr,
              style: text.bodySmall!.copyWith(color: p.err),
            ),
          ),
        const SizedBox(height: MTSpace.md),
        Wrap(
          spacing: MTSpace.sm,
          runSpacing: MTSpace.sm,
          children: [
            OutlinedButton(
              onPressed: () => checkSubscriptions(context, ref, only: sub),
              child: Text(l10n.checkNow),
            ),
            OutlinedButton(
              onPressed: () => runSubscriptionAction(
                context,
                ref,
                (c) => c.setEnabled(sub, !sub.enabled),
              ),
              child: Text(
                sub.enabled ? l10n.pauseSubscription : l10n.resumeSubscription,
              ),
            ),
            OutlinedButton(
              onPressed: () =>
                  showSubscriptionSheet(context, ref, editing: sub),
              child: Text(l10n.editSubscription),
            ),
          ],
        ),
        const SizedBox(height: MTSpace.md),
        // How it is set up, in one quiet card of hairline rows.
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(MTRadius.card),
            border: Border.all(
              color: p.line,
              width: MTThemeX.of(context).hairline,
            ),
          ),
          child: Column(
            children: [
              for (final (i, fact) in facts.indexed) ...[
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MTSpace.md,
                    vertical: MTSpace.sm + 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(fact.$1, style: text.bodySmall)),
                      const SizedBox(width: MTSpace.md),
                      Flexible(
                        child: Text(
                          fact.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
