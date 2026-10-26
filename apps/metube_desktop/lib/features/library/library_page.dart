import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/pill.dart';
import '../clip/clip_state.dart';
import '../setup/setup_dialog.dart';
import 'library_chips.dart';
import 'library_item_view.dart';
import 'library_state.dart';

/// The library: the whole unified library, or the favourites or the
/// offline copies, with the filters in view and three layouts.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key, this.scope = LibraryScope.all});

  final LibraryScope scope;

  /// The place a route's `only=` names.
  static LibraryScope scopeOf(String? only) => switch (only) {
    'favorites' => LibraryScope.favorites,
    'offline' => LibraryScope.offline,
    _ => LibraryScope.all,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final visible = ref.watch(visibleLibraryProvider(scope));
    final all = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    final serverMissing = ref.watch(libraryServerErrorProvider) != null;
    final configured = ref.watch(serverConfigProvider) != null;
    final title = switch (scope) {
      LibraryScope.favorites => l.favorites,
      LibraryScope.offline => l.filterOffline,
      _ => l.navLibrary,
    };
    final offline = all.where((i) => i.isOffline).length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            MTSpace.xl,
            MTSpace.sm,
            MTSpace.xl,
            MTSpace.md,
          ),
          sliver: SliverList.list(
            children: [
              _Heading(
                title: title,
                counts: all.isEmpty
                    ? null
                    : mtMetaLine([
                        l.transcriptsClips(all.length),
                        if (offline > 0) l.desktopOfflineCount(offline),
                      ]),
                mode: options.mode,
                onMode: (m) => unawaited(
                  ref.read(libraryViewProvider.notifier).setMode(m),
                ),
              ),
              const SizedBox(height: MTSpace.md),
              LibraryChips(scope: scope),
              if (serverMissing && all.isNotEmpty) ...[
                const SizedBox(height: MTSpace.md),
                _ServerMissing(onRetry: () => ref.invalidate(historyProvider)),
              ],
            ],
          ),
        ),
        ..._content(context, ref, visible, all, configured),
      ],
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<LibraryItem>> visible,
    List<LibraryItem> all,
    bool configured,
  ) {
    final l = context.mtl;
    // A plain box that scrolls with the page, not a fill: a filling sliver
    // measured the message too short under a large font and squeezed it.
    Widget fill(Widget child) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MTSpace.xxl * 2),
        child: Center(child: child),
      ),
    );
    if (!configured && all.isEmpty) {
      return [
        fill(
          MTEmptyFrame(
            title: l.serverStatusUnconfigured,
            message: l.desktopNoServerMessage,
            actionLabel: l.desktopSetupConnect,
            actionIcon: MTIcons.server,
            onAction: () => unawaited(showSetupDialog(context)),
          ),
        ),
      ];
    }
    final items = visible.valueOrNull;
    if (items == null) {
      if (visible.hasError) {
        return [
          fill(
            MTEmptyFrame(
              title: l.serverStatusOffline,
              message: l.desktopServerPartMissing,
              actionLabel: l.retry,
              onAction: () => ref.invalidate(historyProvider),
            ),
          ),
        ];
      }
      return [fill(const MTSpinner())];
    }
    if (items.isEmpty) {
      return [
        fill(
          all.isEmpty
              ? MTEmptyFrame(
                  title: l.noVideosFound,
                  message: l.desktopEmptyLibraryMessage,
                )
              : MTEmptyFrame(
                  title: l.desktopNoMatchTitle,
                  message: l.desktopNoMatchMessage,
                  actionLabel: l.desktopClearFilters,
                  onAction: ref.read(libraryViewProvider.notifier).clearFilters,
                ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.xl,
          0,
          MTSpace.xl,
          MTSpace.xl,
        ),
        sliver: _Items(items: items),
      ),
    ];
  }
}

/// The items, in the chosen layout, marking the one in the player.
class _Items extends ConsumerWidget {
  const _Items({required this.items});

  final List<LibraryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(libraryViewProvider);
    final view = ref.read(libraryViewProvider.notifier);
    final player = ref.watch(playerProvider);
    return StreamBuilder<MTPlayerState>(
      stream: player.states,
      initialData: player.state,
      builder: (context, snap) {
        final state = snap.data ?? player.state;
        final current = state.current?.canonicalUrl;
        return MTLibrarySliver(
          layout: switch (options.mode) {
            LibraryViewMode.list => MTLibraryLayout.list,
            LibraryViewMode.compact => MTLibraryLayout.compact,
            _ => MTLibraryLayout.grid,
          },
          showLocation: true,
          sort: tableSortFor(options.sort, (s) => unawaited(view.setSort(s))),
          itemCount: items.length,
          itemBuilder: (context, index, columns) {
            final item = items[index];
            final isCurrent = item.canonicalUrl == current;
            return LibraryItemView(
              item: item,
              mode: options.mode,
              columns: columns,
              playing: isCurrent,
              paused: isCurrent && !state.playing,
              // The list on screen becomes the queue, from the clip
              // clicked, as on the phone; a video opens its page and a
              // short its lane.
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

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.counts,
    required this.mode,
    required this.onMode,
  });

  final String title;
  final String? counts;
  final LibraryViewMode mode;
  final ValueChanged<LibraryViewMode> onMode;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l = context.mtl;
    // The title and its counts wrap under each other when the window or
    // the font leaves no room; the layout choice keeps its place.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Wrap(
            spacing: MTSpace.md,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(title, style: text.headlineSmall),
              if (counts case final line?) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: MTSpace.xxs),
                  child: Text(
                    line,
                    style: text.bodySmall?.copyWith(color: p.ink3),
                  ),
                ),
                // The figures behind the counts, a page of their own.
                MTLinkButton(
                  label: l.desktopStatsLink,
                  onPressed: () => GoRouter.of(context).go(EmberRoutes.stats),
                ),
              ],
            ],
          ),
        ),
        for (final (m, label) in [
          (LibraryViewMode.grid, l.viewGrid),
          (LibraryViewMode.list, l.desktopViewTable),
          (LibraryViewMode.compact, l.desktopViewCompact),
        ]) ...[
          const SizedBox(width: MTSpace.xxs),
          EmberPill(label: label, selected: mode == m, onTap: () => onMode(m)),
        ],
      ],
    );
  }
}

/// The library is shown from the last answer because the server is not
/// answering now.
class _ServerMissing extends StatelessWidget {
  const _ServerMissing({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    return Row(
      children: [
        Flexible(
          child: Text(
            l.desktopServerPartMissing,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: p.ink2),
          ),
        ),
        const SizedBox(width: MTSpace.sm),
        MTLinkButton(label: l.retry, onPressed: onRetry),
      ],
    );
  }
}
