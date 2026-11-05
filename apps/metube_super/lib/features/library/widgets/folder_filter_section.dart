import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_media/library.dart';

import '../library_providers.dart';

/// **The server folders, chosen like the platform** and shown as a
/// removable chip in the first row once chosen. Absent while every clip
/// sits at the top of the download directory, which is most servers: the
/// library looks as it would without folder support.
///
/// One row per level: choosing `Ai` adds a row with what is inside it, and
/// tapping the chosen folder again goes back up a level.
class FolderFilterSection extends ConsumerWidget {
  const FolderFilterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    final top = folderCounts(items);
    if (top.isEmpty) return const SizedBox.shrink();

    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final selected = ref.watch(
      libraryViewProvider.select((options) => options.folder),
    );
    final controller = ref.read(libraryViewProvider.notifier);

    String? parentOf(String path) =>
        path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : null;

    Widget chip(String path, int count) {
      final on =
          selected != null &&
          (selected == path || selected.startsWith('$path/'));
      return ChoiceChip(
        label: Text(l10n.platformCount(mtName(path.split('/').last), count)),
        selected: on,
        showCheckmark: false,
        labelStyle: Theme.of(context).textTheme.labelMedium!
            .copyWith(color: on ? p.bg : p.ink2),
        onSelected: (_) =>
            controller.setFolder(selected == path ? parentOf(path) : path),
      );
    }

    Widget row(List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(top: MTSpace.xs),
      child: MTChipRow(children: chips),
    );

    // A level on one row, the chosen folder first so it is in sight.
    List<Widget> level(List<MapEntry<String, int>> entries) {
      bool chosen(String path) =>
          selected != null &&
          (selected == path || selected.startsWith('$path/'));
      return [
        for (final MapEntry(:key, :value) in [
          ...entries.where((e) => chosen(e.key)),
          ...entries.where((e) => !chosen(e.key)),
        ])
          chip(key, value),
      ];
    }

    // The levels under the chosen folder, from the top down.
    final levels = <List<MapEntry<String, int>>>[];
    if (selected != null) {
      final parts = selected.split('/');
      for (var i = 1; i <= parts.length; i++) {
        final below = folderCounts(items, parent: parts.take(i).join('/'));
        if (below.isEmpty) break;
        levels.add(below);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: MTSpace.xl),
        MTSectionHeader(title: l10n.folder),
        const SizedBox(height: MTSpace.sm),
        row([
          ChoiceChip(
            label: Text(l10n.allFolders),
            selected: selected == null,
            showCheckmark: false,
            labelStyle: Theme.of(context).textTheme.labelMedium!
                .copyWith(color: selected == null ? p.bg : p.ink2),
            onSelected: (_) => controller.setFolder(null),
          ),
          ...level(top),
        ]),
        for (final entries in levels) row(level(entries)),
      ],
    );
  }
}
