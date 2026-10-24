import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../data/lists_data.dart';
import '../../router.dart';
import '../../shell/context_menu.dart';
import '../../shell/pill.dart';
import '../../shell/section_header.dart';
import '../clip/clip_state.dart';
import '../library/library_state.dart';
import 'list_actions.dart';
import 'list_card.dart';
import 'list_dialogs.dart';
import 'manage_tags_dialog.dart';

enum _ListChoice { pin, rename, delete }

/// The lists: the three that make themselves, the saved ones (pinned
/// first, then the one played last), and the tags with their counts.
class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await promptPlaylistName(context);
    if (name == null || !context.mounted) return;
    await ref.read(listActionsProvider).create(name);
    if (context.mounted) {
      showMTNotice(
        context,
        message: context.mtl.playlistCreated,
        kind: MTNoticeKind.done,
      );
    }
  }

  Future<void> _play(BuildContext context, WidgetRef ref, String id) async {
    final router = GoRouter.of(context);
    final view = await ref.read(playlistViewProvider(id).future);
    await ref.read(listActionsProvider).play(router, view);
  }

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    SavedPlaylist list,
    Offset at,
  ) async {
    final l = context.mtl;
    final actions = ref.read(listActionsProvider);
    final choice = await showEmberMenu(context, at, [
      EmberMenuEntry(
        _ListChoice.pin,
        null,
        list.pinned ? l.unpinPlaylist : l.pinPlaylist,
      ),
      EmberMenuEntry(_ListChoice.rename, null, l.rename),
      const EmberMenuEntry.divider(),
      EmberMenuEntry(_ListChoice.delete, MTIcons.trash, l.delete, danger: true),
    ]);
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _ListChoice.pin:
        await actions.setPinned(list.id, !list.pinned);
      case _ListChoice.rename:
        final name = await promptPlaylistName(context, initial: list.name);
        if (name != null) await actions.rename(list.id, name);
      case _ListChoice.delete:
        if (!await confirmDeletePlaylist(context, list.name)) return;
        await actions.delete(list.id);
        if (context.mounted) {
          showMTNotice(context, message: l.playlistDeleted);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final router = GoRouter.of(context);
    final lists = ref.watch(playlistsProvider);
    final smart = ref.watch(smartListsProvider);
    final tags = ref.watch(tagCountsProvider).valueOrNull ?? const {};
    final library = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    final covers = {for (final i in library) i.canonicalUrl: i.thumbnail};

    Widget section(String title, {String? trailing, Widget? action}) => Padding(
      padding: const EdgeInsets.only(top: MTSpace.xl, bottom: MTSpace.md),
      child: EmberSectionHeader(
        title: title,
        trailing: trailing,
        action: action,
      ),
    );

    final saved = lists.valueOrNull ?? const <SavedPlaylist>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.xl,
        MTSpace.sm,
        MTSpace.xl,
        MTSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.navPlaylists, style: text.headlineSmall)),
              Flexible(
                child: EmberPill(
                  label: l.newPlaylistAction,
                  icon: MTIcons.plus,
                  selected: false,
                  onTap: () => unawaited(_create(context, ref)),
                ),
              ),
            ],
          ),
          section(l.smartPlaylists),
          Wrap(
            spacing: MTSpace.md,
            runSpacing: MTSpace.md,
            children: [
              for (final list in smart)
                ListCard(
                  title: switch (list.kind) {
                    SmartListKind.favorites => l.favorites,
                    SmartListKind.latest => l.latestAdditions,
                    SmartListKind.offline => l.offlineSmartList,
                  },
                  subtitle: mtMetaLine([
                    l.queueItemsCount(list.items.length),
                    l.autoBuilt,
                  ]),
                  icon: switch (list.kind) {
                    SmartListKind.favorites => MTIcons.favorite,
                    SmartListKind.latest => MTIcons.library,
                    SmartListKind.offline => MTIcons.download,
                  },
                  covers: [for (final i in list.items.take(4)) i.thumbnail],
                  // The phone plays a smart list at a tap; it has no page.
                  onOpen: () {
                    if (list.items.isEmpty) return;
                    unawaited(
                      openFromList(ref, router, [
                        for (final i in list.items) toPlaylistItem(i),
                      ], 0),
                    );
                  },
                ),
            ],
          ),
          section(l.yourPlaylists, trailing: l.sortedByLastPlayed),
          if (lists.hasError && saved.isEmpty)
            Text(
              l.errorGeneric(lists.error.toString()),
              style: text.bodySmall?.copyWith(color: p.err),
            )
          else if (saved.isEmpty && lists.hasValue)
            Row(
              children: [
                Flexible(
                  child: Text(
                    l.noPlaylistsMessage,
                    style: text.bodySmall?.copyWith(color: p.ink3),
                  ),
                ),
                const SizedBox(width: MTSpace.sm),
                MTLinkButton(
                  label: l.newPlaylistAction,
                  onPressed: () => unawaited(_create(context, ref)),
                ),
              ],
            )
          else
            Wrap(
              spacing: MTSpace.md,
              runSpacing: MTSpace.md,
              children: [
                for (final list in saved)
                  ListCard(
                    key: ValueKey(list.id),
                    title: list.name,
                    subtitle: l.queueItemsCount(list.items.length),
                    pinned: list.pinned,
                    covers: [
                      for (final e in list.items.take(4))
                        covers[e.canonicalUrl] ?? e.cachedThumb,
                    ],
                    onOpen: () => router.go(EmberRoutes.playlist(list.id)),
                    onPlay: list.items.isEmpty
                        ? null
                        : () => unawaited(_play(context, ref, list.id)),
                    onMenu: (at) => unawaited(_menu(context, ref, list, at)),
                  ),
              ],
            ),
          section(
            l.yourTags,
            trailing: tags.isEmpty ? null : l.tagsOpenFiltered,
            action: Padding(
              padding: const EdgeInsetsDirectional.only(start: MTSpace.md),
              child: MTLinkButton(
                label: l.manageTags,
                onPressed: () => unawaited(showManageTagsDialog(context)),
              ),
            ),
          ),
          if (tags.isEmpty)
            Text(
              l.desktopNoTags,
              style: text.bodySmall?.copyWith(color: p.ink3),
            )
          else
            Wrap(
              spacing: MTSpace.xs,
              runSpacing: MTSpace.xs,
              children: [
                for (final tag in (tags.keys.toList()..sort()))
                  EmberPill(
                    label: '# $tag  ${tags[tag]}',
                    selected: false,
                    onTap: () {
                      ref.read(libraryViewProvider.notifier).showTag(tag);
                      router.go(EmberRoutes.library);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
