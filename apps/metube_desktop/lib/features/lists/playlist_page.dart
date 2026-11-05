import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/lists_data.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/pill.dart';
import 'list_actions.dart';
import 'list_dialogs.dart';
import 'playlist_line.dart';

/// One saved list: its actions, then its clips in its order, which a drag
/// by the grip changes. A click plays the list from that clip.
class PlaylistPage extends ConsumerWidget {
  const PlaylistPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final asked = ref.watch(playlistViewProvider(id));
    final view = asked.valueOrNull;
    Widget centered(Widget child) => Center(
      child: Padding(padding: const EdgeInsets.all(MTSpace.xl), child: child),
    );
    if (view == null) {
      return centered(
        asked.hasError
            ? MTEmptyFrame(
                title: l.emptyPlaylist,
                message: l.errorGeneric(asked.error.toString()),
                actionLabel: l.tryAgain,
                onAction: () => ref.invalidate(playlistsProvider),
              )
            : const MTSpinner(),
      );
    }
    if (view.playlist == null) {
      return centered(
        MTEmptyFrame(
          title: l.playlistDetails,
          message: l.noPlaylistsMessage,
          actionLabel: l.navPlaylists,
          onAction: () => context.go(EmberRoutes.playlists),
        ),
      );
    }
    final player = ref.watch(playerProvider);
    return LayoutBuilder(
      builder: (context, box) {
        // The readable width, centred, as every list of rows on a wide
        // window.
        final side = math.max(
          MTSpace.xl,
          (box.maxWidth - MTBreakpoint.readable) / 2,
        );
        return StreamBuilder<MTPlayerState>(
          stream: player.states,
          initialData: player.state,
          builder: (context, snap) =>
              _Lines(view: view, side: side, state: snap.data ?? player.state),
        );
      },
    );
  }
}

class _Lines extends ConsumerWidget {
  const _Lines({required this.view, required this.side, required this.state});

  final PlaylistView view;
  final double side;
  final MTPlayerState state;

  void _remove(BuildContext context, WidgetRef ref, PlaylistItem item, int i) {
    final l = context.mtl;
    final actions = ref.read(listActionsProvider);
    final id = view.playlist!.id;
    unawaited(actions.remove(id, item));
    showMTNotice(
      context,
      message: l.removedFromPlaylist,
      actionLabel: l.undo,
      onAction: () => unawaited(actions.undoRemove(id, item, i)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final router = GoRouter.of(context);
    final actions = ref.read(listActionsProvider);
    final current = state.current?.canonicalUrl;
    final items = view.items;
    return ReorderableListView.builder(
      // The grip is drawn, not Material's icon, and only it starts a drag,
      // so a click on the line still plays.
      buildDefaultDragHandles: false,
      padding: EdgeInsets.fromLTRB(side, MTSpace.sm, side, MTSpace.xl),
      header: _Header(view: view),
      itemCount: items.length,
      onReorderItem: (from, to) =>
          unawaited(actions.reorder(view.playlist!.id, from, to)),
      itemBuilder: (context, i) {
        final item = items[i];
        final missing = view.isMissing(item);
        return PlaylistLine(
          key: ValueKey(item.canonicalUrl),
          index: i,
          item: item,
          missing: missing,
          current: !missing && item.canonicalUrl == current,
          playing: state.playing,
          onTap: () {
            if (missing) {
              showMTNotice(
                context,
                message: l.itemUnavailable,
                kind: MTNoticeKind.failed,
              );
              return;
            }
            // The place among what can play, not among the lines shown.
            final start = view.playable.indexWhere(
              (p) => p.canonicalUrl == item.canonicalUrl,
            );
            unawaited(actions.play(router, view, start: start));
          },
          onRemove: () => _remove(context, ref, item, i),
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.view});

  final PlaylistView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final router = GoRouter.of(context);
    final actions = ref.read(listActionsProvider);
    final list = view.playlist!;
    final playable = view.playable.isNotEmpty;

    Future<void> rename() async {
      final name = await promptPlaylistName(context, initial: list.name);
      if (name != null) await actions.rename(list.id, name);
    }

    Future<void> delete() async {
      if (!await confirmDeletePlaylist(context, list.name)) return;
      await actions.delete(list.id);
      if (!context.mounted) return;
      showMTNotice(context, message: l.playlistDeleted);
      router.go(EmberRoutes.playlists);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            list.name,
            textDirection: mtTextDirectionOf(
              list.name,
              Directionality.of(context),
            ),
            style: text.headlineSmall,
          ),
          const SizedBox(height: MTSpace.xxs),
          Text(
            mtMetaLine([
              l.queueItemsCount(list.items.length),
              if (list.pinned) l.desktopPinned,
            ]),
            style: text.bodySmall?.copyWith(color: p.ink3),
          ),
          const SizedBox(height: MTSpace.md),
          Wrap(
            spacing: MTSpace.sm,
            runSpacing: MTSpace.sm,
            children: [
              if (playable) ...[
                EmberPill(
                  label: l.playAll,
                  icon: MTIcons.playFill,
                  selected: false,
                  onTap: () => unawaited(actions.play(router, view)),
                ),
                EmberPill(
                  label: l.shuffle,
                  icon: MTIcons.shuffle,
                  selected: false,
                  onTap: () =>
                      unawaited(actions.play(router, view, shuffle: true)),
                ),
                EmberPill(
                  // The phone's headphones; a computer has no background
                  // to send it to, so it says what it does.
                  label: l.audioOnly,
                  icon: MTIcons.headphones,
                  selected: false,
                  onTap: () =>
                      unawaited(actions.play(router, view, audioOnly: true)),
                ),
              ],
              EmberPill(
                label: list.pinned ? l.unpinPlaylist : l.pinPlaylist,
                selected: list.pinned,
                onTap: () =>
                    unawaited(actions.setPinned(list.id, !list.pinned)),
              ),
              EmberPill(
                label: l.rename,
                selected: false,
                onTap: () => unawaited(rename()),
              ),
              if (view.missing.isNotEmpty)
                EmberPill(
                  label: l.removeUnavailable(view.missing.length),
                  selected: false,
                  onTap: () =>
                      unawaited(actions.removeMissing(list.id, view.missing)),
                ),
              EmberPill(
                label: l.delete,
                icon: MTIcons.trash,
                selected: false,
                onTap: () => unawaited(delete()),
              ),
            ],
          ),
          if (list.items.isEmpty) ...[
            const SizedBox(height: MTSpace.xxl),
            Center(
              child: MTEmptyFrame(
                title: l.emptyPlaylist,
                message: l.emptyPlaylistMessage,
                actionLabel: l.navLibrary,
                onAction: () => router.go(EmberRoutes.library),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
