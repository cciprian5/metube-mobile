import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../playlists/playlists_providers.dart';
import '../library_providers.dart';

/// **The tags inside the sort and filter sheet: compound filtering**
/// (requested 2026-09-02).
///
/// Every tag is a chip with three states cycled by tapping: neutral,
/// included, excluded. Included tags are combined with OR (widening) and
/// excluded ones subtracted (narrowing), so tapping alone covers every
/// combination with no dropdown and no settings screen. It used to be a
/// second row above the list, which pushed the first clip down on every
/// visit; the chosen tags still show in the first row, removable.
class TagFilterSection extends ConsumerWidget {
  const TagFilterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts =
        ref.watch(tagCountsProvider).valueOrNull ?? const <String, int>{};
    if (counts.isEmpty) return const SizedBox.shrink();

    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final p = MTThemeX.of(context).palette;
    final names = counts.keys.toList()..sort();
    final anyActive =
        options.tags.isNotEmpty || options.excludedTags.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: MTSpace.xl),
        MTSectionHeader(title: l10n.tags),
        const SizedBox(height: MTSpace.md),
        Wrap(
          spacing: MTSpace.xs,
          runSpacing: MTSpace.xs,
          children: [
            if (anyActive)
              ActionChip(
                avatar: MTIcon(MTIcons.close, size: 14, color: p.ink2),
                label: Text(l10n.clear),
                onPressed: controller.clearTags,
              ),
            for (final tag in names)
              _TagChip(
                tag: tag,
                count: counts[tag] ?? 0,
                included: options.tags.contains(tag),
                excluded: options.excludedTags.contains(tag),
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.cycleTag(tag);
                },
              ),
          ],
        ),
        const SizedBox(height: MTSpace.sm),
        Text(l10n.tagFilterHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.count,
    required this.included,
    required this.excluded,
    required this.onTap,
  });

  final String tag;
  final int count;
  final bool included;
  final bool excluded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    // Included in ink like every chosen chip; an exclusion is read before
    // the text: a minus sign and a strikethrough, in the error colour, so
    // subtraction is never mistaken for addition at a glance.
    final (bg, fg) = switch ((included, excluded)) {
      (true, _) => (p.ink, p.bg),
      (_, true) => (p.err.withValues(alpha: 0.14), p.err),
      _ => (Colors.transparent, p.ink2),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTRadius.chip),
        side: BorderSide(
          color: excluded
              ? p.err
              : included
              ? p.ink
              : p.line2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpace.md,
            vertical: MTSpace.xs,
          ),
          child: Text(
            // "# Ai 45" rendered with the number before the name; isolation
            // pins it.
            mtLtrRun('${excluded ? '− ' : '# '}$tag  $count'),
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: fg,
              decoration: excluded ? TextDecoration.lineThrough : null,
              decorationColor: fg,
            ),
          ),
        ),
      ),
    );
  }
}
