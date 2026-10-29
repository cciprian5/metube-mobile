import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../router.dart';
import '../../shell/context_menu.dart';
import '../../shell/pill.dart';
import 'library_state.dart';
import 'platform_label.dart';

/// The filters, always in view above the library: the kind of clip as
/// pills, and **the platforms and the tags each behind one pill that opens
/// a menu**. Laid out as pills too, eight platforms and every tag wrapped to
/// a second and a third row of equal pills above the clips, growing with
/// each tag.
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
    final platforms = ref.watch(platformCountsProvider(scope));
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
        if (platforms.length > 1 || options.platform != null)
          Builder(
            builder: (chip) => EmberPill(
              label: switch (options.platform) {
                final chosen? => platformLabel(l, chosen),
                null => l.platform,
              },
              selected: options.platform != null,
              opensMenu: true,
              onTap: () => _choosePlatform(chip, ref, platforms),
            ),
          ),
        if (tags.isNotEmpty)
          Builder(
            builder: (chip) => EmberPill(
              label: l.tags,
              count: switch (options.tags.length +
                  options.excludedTags.length) {
                0 => null,
                final n => n,
              },
              selected:
                  options.tags.isNotEmpty || options.excludedTags.isNotEmpty,
              opensMenu: true,
              onTap: () => _chooseTags(chip, ref, tags),
            ),
          ),
      ],
    );
  }

  /// Opens under the pill that was clicked.
  static Offset _under(BuildContext chip) {
    final box = chip.findRenderObject()! as RenderBox;
    return box.localToGlobal(box.size.bottomLeft(Offset.zero));
  }

  Future<void> _choosePlatform(
    BuildContext chip,
    WidgetRef ref,
    List<MapEntry<MediaPlatform, int>> platforms,
  ) async {
    final l = chip.mtl;
    final chosen = ref.read(libraryViewProvider).platform;
    final picked = await showEmberMenu<MediaPlatform>(chip, _under(chip), [
      for (final MapEntry(key: platform, value: count) in platforms)
        EmberMenuEntry(
          platform,
          platform == chosen ? MTIcons.check : null,
          platformLabel(l, platform),
          shortcut: '$count',
        ),
    ]);
    if (picked != null) {
      ref.read(libraryViewProvider.notifier).togglePlatform(picked);
    }
  }

  /// A tag picked once is shown, twice is hidden, a third time is let go,
  /// as the pills did; the menu reopens until it is dismissed, so several
  /// tags can be set in one go.
  Future<void> _chooseTags(
    BuildContext chip,
    WidgetRef ref,
    List<String> tags,
  ) async {
    while (chip.mounted) {
      final options = ref.read(libraryViewProvider);
      final picked = await showEmberMenu<String>(chip, _under(chip), [
        for (final tag in tags)
          EmberMenuEntry(
            tag,
            options.tags.contains(tag)
                ? MTIcons.check
                : options.excludedTags.contains(tag)
                ? MTIcons.close
                : null,
            mtName('#$tag'),
          ),
      ]);
      if (picked == null) return;
      ref.read(libraryViewProvider.notifier).cycleTag(picked);
    }
  }
}
