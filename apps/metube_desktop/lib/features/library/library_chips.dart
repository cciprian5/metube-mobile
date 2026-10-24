import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../router.dart';
import '../../shell/pill.dart';
import 'library_state.dart';
import 'platform_label.dart';

/// The filters, always in view above the library: the kind of clip, the
/// platforms with their live counts, and the user's tags. On a phone these
/// hide in a sheet; a window has the room to keep them visible.
class LibraryChips extends ConsumerWidget {
  const LibraryChips({super.key, required this.scope});

  /// The place the library is shown for; favourites is a place of its own
  /// in the sidebar, so its chip and that entry are one state.
  final LibraryScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final view = ref.read(libraryViewProvider.notifier);
    final platforms = ref.watch(platformCountsProvider);
    final tags = ref.watch(libraryTagsProvider);
    final noFilter =
        options.type == MediaTypeFilter.all &&
        options.platform == null &&
        options.folder == null &&
        options.tags.isEmpty &&
        options.excludedTags.isEmpty;

    void type(MediaTypeFilter t) =>
        view.setType(options.type == t ? MediaTypeFilter.all : t);

    return Wrap(
      spacing: MTSpace.xs,
      runSpacing: MTSpace.xs,
      children: [
        EmberPill(
          label: l.filterAll,
          selected: noFilter && scope == LibraryScope.all,
          onTap: () {
            view.clearFilters();
            if (scope != LibraryScope.all) context.go(EmberRoutes.library);
          },
        ),
        EmberPill(
          label: l.favorites,
          icon: MTIcons.favorite,
          selected: scope == LibraryScope.favorites,
          onTap: () => context.go(
            scope == LibraryScope.favorites
                ? EmberRoutes.library
                : EmberRoutes.favorites,
          ),
        ),
        for (final (t, label) in [
          (MediaTypeFilter.video, l.filterVideo),
          (MediaTypeFilter.audio, l.filterAudio),
          (MediaTypeFilter.shorts, l.shortsFilter),
        ])
          EmberPill(
            label: label,
            selected: options.type == t,
            onTap: () => type(t),
          ),
        // The folder chosen in the sidebar, here too so it can be seen
        // and taken off where the clips are.
        if (options.folder case final folder?)
          EmberPill(
            label: mtName(folder),
            icon: MTIcons.folder,
            selected: true,
            onTap: () => view.setFolder(null),
          ),
        // A single platform is no choice at all, as in Lite.
        if (platforms.length > 1)
          for (final MapEntry(key: platform, value: count) in platforms)
            EmberPill(
              label: l.platformCount(platformLabel(l, platform), count),
              selected: options.platform == platform,
              onTap: () => view.togglePlatform(platform),
            ),
        for (final tag in tags)
          EmberPill(
            label: '#$tag',
            selected: options.tags.contains(tag),
            struck: options.excludedTags.contains(tag),
            onTap: () => view.cycleTag(tag),
          ),
      ],
    );
  }
}
