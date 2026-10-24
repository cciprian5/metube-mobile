import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/lists_data.dart';
import '../../shell/shell_metrics.dart';
import 'list_actions.dart';

/// Every tag with its count, to rename or delete. Renaming onto a tag that
/// already exists merges the two; deleting takes the tag off the clips and
/// leaves the clips.
Future<void> showManageTagsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ManageTags());

class _ManageTags extends ConsumerWidget {
  const _ManageTags();

  Future<void> _rename(BuildContext context, WidgetRef ref, String tag) async {
    final l = context.mtl;
    final name = (await promptMTText(
      context,
      title: l.renameTag,
      confirmLabel: l.rename,
      initialValue: tag,
      hintText: l.newTagHint,
    ))?.trim();
    if (name == null || name.isEmpty || name == tag) return;
    await ref.read(listActionsProvider).renameTag(tag, name);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String tag) async {
    final l = context.mtl;
    final sure = await showMTConfirm(
      context,
      title: l.deleteTag,
      message: l.deleteTagConfirm(mtName(tag)),
      confirmLabel: l.delete,
      cancelLabel: l.cancel,
      destructive: true,
    );
    if (sure) await ref.read(listActionsProvider).deleteTag(tag);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final counts = ref.watch(tagCountsProvider).valueOrNull ?? const {};
    final tags = counts.keys.toList()..sort();
    return AlertDialog(
      title: Text(l.manageTags),
      content: SizedBox(
        width: EmberShellSize.smallDialog,
        child: tags.isEmpty
            ? Text(
                l.desktopNoTags,
                style: text.bodySmall?.copyWith(color: p.ink3),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final tag in tags)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: MTSpace.xxs,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '# $tag',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(color: p.ink),
                              ),
                            ),
                            Text(
                              '${counts[tag]}',
                              style: text.labelSmall?.tabular.copyWith(
                                color: p.ink3,
                              ),
                            ),
                            const SizedBox(width: MTSpace.md),
                            MTLinkButton(
                              label: l.rename,
                              onPressed: () =>
                                  unawaited(_rename(context, ref, tag)),
                            ),
                            const SizedBox(width: MTSpace.sm),
                            MTLinkButton(
                              label: l.delete,
                              onPressed: () =>
                                  unawaited(_delete(context, ref, tag)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.done),
        ),
      ],
    );
  }
}
