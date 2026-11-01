import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shared/platform_label.dart';
import '../library_providers.dart';
import '../local_item.dart';
import 'sort_sheet.dart';

/// A filter chip of uniform shape (the Wahaj reference).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: Theme.of(context).textTheme.labelMedium!
          .copyWith(color: selected ? p.bg : p.ink2),
      onSelected: (_) => onTap(),
    );
  }
}

/// **The library's one chip row**: the chosen platform first and removable,
/// then all, favourites, shorts, video, audio. The platforms are chosen in
/// the sort sheet, so no second row pushes the first clip down.
class LibraryFilterChips extends ConsumerWidget {
  const LibraryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);

    void toggleType(MediaTypeFilter type) =>
        controller.setType(options.type == type ? MediaTypeFilter.all : type);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (options.platform case final platform?)
            MTActiveFilterChip(
              label: platformLabel(l10n, platform),
              onDeleted: () => controller.setPlatform(null),
              onPressed: () => showSortSheet(context, ref),
            ),
          _Chip(
            label: l10n.filterAll,
            selected: options.scope == LocalScope.all,
            onTap: () => controller.setScope(LocalScope.all),
          ),
          const SizedBox(width: MTSpace.xs),
          // The favourites chip is the first filter after "all", in ink
          // like every chosen chip: the crimson is for the heart itself.
          _Chip(
            label: l10n.favorites,
            selected: options.scope == LocalScope.favorites,
            onTap: () => controller.setScope(LocalScope.favorites),
          ),
          const SizedBox(width: MTSpace.md),
          // **Shorts in sight rather than past the edge** (device check
          // 2026-09-05): it was last in the row, so it was invisible
          // without a horizontal scroll that nothing hinted at, with a
          // whole path behind it.
          _Chip(
            label: l10n.shortsFilter,
            selected: options.type == MediaTypeFilter.shorts,
            onTap: () => toggleType(MediaTypeFilter.shorts),
          ),
          const SizedBox(width: MTSpace.xs),
          _Chip(
            label: l10n.filterVideo,
            selected: options.type == MediaTypeFilter.video,
            onTap: () => toggleType(MediaTypeFilter.video),
          ),
          const SizedBox(width: MTSpace.xs),
          _Chip(
            label: l10n.filterAudio,
            selected: options.type == MediaTypeFilter.audio,
            onTap: () => toggleType(MediaTypeFilter.audio),
          ),
        ],
      ),
    );
  }
}

/// The platform filter **with live counts** (Lite specific), inside the
/// sort sheet. It disappears entirely when the library holds only one
/// platform.
class PlatformFilterChips extends ConsumerWidget {
  const PlatformFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final counts = ref.watch(platformCountsProvider);
    if (counts.length < 2) return const SizedBox.shrink();

    final selected = ref.watch(
      libraryViewProvider.select((options) => options.platform),
    );
    final controller = ref.read(libraryViewProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: MTSpace.xl),
        MTSectionHeader(title: l10n.platform),
        const SizedBox(height: MTSpace.md),
        Wrap(
          spacing: MTSpace.xs,
          runSpacing: MTSpace.xs,
          children: [
            _Chip(
              label: l10n.allPlatforms,
              selected: selected == null,
              onTap: () => controller.setPlatform(null),
            ),
            for (final MapEntry(:key, :value) in counts)
              _Chip(
                label: l10n.platformCount(platformLabel(l10n, key), value),
                selected: selected == key,
                onTap: () =>
                    controller.setPlatform(selected == key ? null : key),
              ),
          ],
        ),
      ],
    );
  }
}
