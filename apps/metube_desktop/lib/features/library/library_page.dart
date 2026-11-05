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
import '../add/add_dialog.dart';
import '../clip/clip_state.dart';
import '../setup/setup_dialog.dart';
import 'library_chips.dart';
import 'library_heading.dart';
import 'library_skeleton.dart';
import 'library_item_view.dart';
import 'library_scroll.dart';
import 'library_state.dart';
import 'selection.dart';
import 'selection_bar.dart';

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
    // What this place holds before any chip: its own count, and the
    // message when it holds nothing yet.
    final held = switch (scope) {
      LibraryScope.favorites => all.where((i) => i.favorite).length,
      LibraryScope.offline => offline,
      _ => all.length,
    };

    return SelectionFrame(
      items: visible.valueOrNull ?? const [],
      child: LibraryScroll(
        place: libraryPlaceKey(scope, options),
        builder: (controller) => CustomScrollView(
          controller: controller,
          slivers: [
            PinnedHeaderSliver(
              child: PinnedLibraryHeading(
                child: LibraryHeading(
                  title: title,
                  counts: all.isEmpty
                      ? null
                      : mtMetaLine([
                          l.transcriptsClips(held),
                          if (scope == LibraryScope.all && offline > 0)
                            l.desktopOfflineCount(offline),
                        ]),
                  mode: options.mode,
                  onMode: (m) => unawaited(
                    ref.read(libraryViewProvider.notifier).setMode(m),
                  ),
                  sort: options.sort,
                  onSort: (s) => unawaited(
                    ref.read(libraryViewProvider.notifier).setSort(s),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                MTSpace.xl,
                MTSpace.xs,
                MTSpace.xl,
                MTSpace.md,
              ),
              sliver: SliverList.list(
                children: [
                  LibraryChips(scope: scope),
                  if (serverMissing && all.isNotEmpty) ...[
                    const SizedBox(height: MTSpace.md),
                    _ServerMissing(
                      onRetry: () => ref.invalidate(historyProvider),
                    ),
                  ],
                ],
              ),
            ),
            ..._content(context, ref, visible, all, configured, held),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<LibraryItem>> visible,
    List<LibraryItem> all,
    bool configured,
    int held,
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
      return [fill(const LibrarySkeleton())];
    }
    if (items.isEmpty) {
      return [
        fill(
          all.isEmpty
              ? MTEmptyFrame(
                  title: l.noVideosFound,
                  message: l.desktopEmptyLibraryMessage,
                  actionLabel: l.addLinkFab,
                  actionIcon: MTIcons.addlink,
                  onAction: () => unawaited(openAddDialog(context)),
                )
              // Nothing here yet is not a filter that hides too much.
              : held == 0 && scope == LibraryScope.favorites
              ? MTEmptyFrame(
                  title: l.desktopNoFavoritesTitle,
                  message: l.desktopNoFavoritesMessage,
                  actionLabel: l.navLibrary,
                  onAction: () => GoRouter.of(context).go(EmberRoutes.library),
                )
              : held == 0 && scope == LibraryScope.offline
              ? MTEmptyFrame(
                  title: l.desktopNoOfflineTitle,
                  message: l.desktopNoOfflineMessage,
                  actionLabel: l.navLibrary,
                  onAction: () => GoRouter.of(context).go(EmberRoutes.library),
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
    final chosen = ref.watch(librarySelectionProvider).urls;
    final order = [for (final i in items) i.canonicalUrl];
    // A new layout, order or filter fades the list in; typing a search
    // does not, or every key would flash it.
    return SliverFadeOnChange(
      value: (
        options.mode,
        options.sort,
        options.type,
        options.platform,
        options.channel,
        options.folder,
        options.tags.join(' '),
        options.excludedTags.join(' '),
      ),
      sliver: StreamBuilder<MTPlayerState>(
        stream: player.states,
        initialData: player.state,
        builder: (context, snap) {
          final state = snap.data ?? player.state;
          final current = state.current?.canonicalUrl;
          return MTLibrarySliver(
            pinHeader: true,
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
                selected: chosen.contains(item.canonicalUrl),
                choosing: chosen.isNotEmpty,
                onChoose: () => ref
                    .read(librarySelectionProvider.notifier)
                    .click(item.canonicalUrl, order),
                onToggle: () => ref
                    .read(librarySelectionProvider.notifier)
                    .toggle(item.canonicalUrl),
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
      ),
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
