import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_media/library.dart';

import '../library_providers.dart';
import 'sort_sheet.dart';

/// **The library's one chip row**: the active sheet filters first and
/// removable, then all, favourites, offline, server, shorts, video, audio.
/// The platforms, folders and tags are chosen in the sort and filter sheet,
/// so no second row pushes the first clip down.
class LibraryFilterChips extends ConsumerWidget {
  const LibraryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final x = MTThemeX.of(context);
    void openSheet() => showSortSheet(context, ref);
    ChoiceChip chip(String label, bool selected, VoidCallback onTap) =>
        ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          labelStyle: Theme.of(context).textTheme.labelMedium!
              .copyWith(color: selected ? x.palette.bg : x.palette.ink2),
          onSelected: (_) => onTap(),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // **The active filters, first and removable.** The platform,
          // folder and tags are chosen in the sort sheet, and the channel
          // from an item's sheet, a screen already left by the time the
          // list narrows: without a chip here the library would simply
          // look half empty.
          if (options.channel case final channel?)
            MTGrowIn(
              key: const ValueKey('chip-channel'),
              child: MTActiveFilterChip(
                icon: Icons.subscriptions_rounded,
                label: channel,
                onDeleted: () => controller.toggleChannel(null),
              ),
            ),
          if (options.folder case final folder?)
            MTGrowIn(
              key: const ValueKey('chip-folder'),
              child: MTActiveFilterChip(
                icon: Icons.folder_rounded,
                label: mtName(folder),
                onDeleted: () => controller.setFolder(null),
                onPressed: openSheet,
              ),
            ),
          if (options.platform case final platform?)
            MTGrowIn(
              key: const ValueKey('chip-platform'),
              child: MTActiveFilterChip(
                label: platform.label,
                onDeleted: () => controller.setPlatform(null),
                onPressed: openSheet,
              ),
            ),
          for (final tag in options.tags)
            MTGrowIn(
              key: ValueKey('chip-tag-$tag'),
              child: MTActiveFilterChip(
                label: mtLtrRun('# $tag'),
                onDeleted: () => controller.removeTag(tag),
                onPressed: openSheet,
              ),
            ),
          for (final tag in options.excludedTags)
            MTGrowIn(
              key: ValueKey('chip-not-$tag'),
              child: MTActiveFilterChip(
                label: mtLtrRun('− $tag'),
                struck: true,
                onDeleted: () => controller.removeTag(tag),
                onPressed: openSheet,
              ),
            ),
          chip(
            l10n.filterAll,
            options.scope == LibraryScope.all,
            () => controller.setScope(LibraryScope.all),
          ),
          const SizedBox(width: MTSpace.xs),
          // The favourites chip is the first filter after "all", in ink
          // like every chosen chip: the crimson is for the heart itself.
          chip(
            l10n.favorites,
            options.scope == LibraryScope.favorites,
            () => controller.setScope(LibraryScope.favorites),
          ),
          const SizedBox(width: MTSpace.xs),
          chip(
            l10n.filterOffline,
            options.scope == LibraryScope.offline,
            () => controller.setScope(LibraryScope.offline),
          ),
          const SizedBox(width: MTSpace.xs),
          chip(
            l10n.filterServer,
            options.scope == LibraryScope.onServer,
            () => controller.setScope(LibraryScope.onServer),
          ),
          const SizedBox(width: MTSpace.md),
          // **Shorts in sight rather than past the edge** (device check
          // 2026-09-05): it is a whole path, and it was the last chip
          // in a row that needed a horizontal scroll with nothing to
          // hint at it.
          chip(
            l10n.shortsFilter,
            options.type == MediaTypeFilter.shorts,
            () => controller.setType(
              options.type == MediaTypeFilter.shorts
                  ? MediaTypeFilter.all
                  : MediaTypeFilter.shorts,
            ),
          ),
          const SizedBox(width: MTSpace.xs),
          chip(
            l10n.filterVideo,
            options.type == MediaTypeFilter.video,
            () => controller.setType(
              options.type == MediaTypeFilter.video
                  ? MediaTypeFilter.all
                  : MediaTypeFilter.video,
            ),
          ),
          const SizedBox(width: MTSpace.xs),
          chip(
            l10n.filterAudio,
            options.type == MediaTypeFilter.audio,
            () => controller.setType(
              options.type == MediaTypeFilter.audio
                  ? MediaTypeFilter.all
                  : MediaTypeFilter.audio,
            ),
          ),
        ],
      ),
    );
  }
}
