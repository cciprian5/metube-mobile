import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/folders_data.dart';
import '../../data/transcripts_data.dart';
import 'backup_actions.dart';
import 'simple_panes.dart';

/// How many clips have their words here, and the room they take; counted
/// again each time settings open, as transcripts arrive in the meantime.
final transcriptsSummaryProvider = FutureProvider.autoDispose<(int, int)>((
  ref,
) async {
  final store = ref.watch(transcriptStoreProvider);
  if (store == null) return (0, 0);
  final index = await ref.watch(transcriptIndexProvider.future);
  return (index.length, await store.sizeBytes());
});

/// The words kept for each clip: how many, moving them to and from a
/// phone, and removing them all.
class TranscriptsPane extends ConsumerWidget {
  const TranscriptsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final summary = ref.watch(transcriptsSummaryProvider).valueOrNull;
    final none = summary == null || summary.$1 == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.desktopTranscriptsHelp,
          style: text.bodyMedium?.copyWith(color: p.ink2),
        ),
        const SizedBox(height: MTSpace.md),
        SettingLine(
          title: l.transcriptsClips(summary?.$1 ?? 0),
          value: summary == null || none ? null : mtFormatSize(summary.$2),
        ),
        SettingLine(
          title: l.transcriptsExport,
          hint: l.desktopTranscriptsExportHint,
          trailing: MTLinkButton(
            label: l.transcriptsExport,
            onPressed: none ? null : () => unawaited(_export(context, ref)),
          ),
        ),
        SettingLine(
          title: l.transcriptsImport,
          hint: l.desktopTranscriptsImportHint,
          trailing: MTLinkButton(
            label: l.transcriptsImport,
            onPressed: () => unawaited(_import(context, ref)),
          ),
        ),
        SettingLine(
          title: l.transcriptsDeleteAll,
          trailing: MTLinkButton(
            label: l.transcriptsDeleteAll,
            onPressed: none ? null : () => unawaited(_deleteAll(context, ref)),
          ),
        ),
      ],
    );
  }

  /// Every transcript in the phone's import file, saved where the user
  /// chooses.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final store = ref.read(transcriptStoreProvider);
    if (store == null) return;
    final all = await store.readAll().toList();
    final folders = ref.read(desktopFoldersProvider);
    const name = 'transcripts.json';
    final saved = await folders.saveText(
      name: name,
      text: TranscriptBundle.encode(all),
    );
    if (saved == null || !context.mounted) return;
    final l = context.mtl;
    showMTNotice(
      context,
      message: l.desktopExported(name),
      actionLabel: l.desktopShowInFolder,
      onAction: () => unawaited(folders.reveal(saved)),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    await chooseAndImport(context, ref);
    ref.invalidate(transcriptsSummaryProvider);
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l = context.mtl;
    final sure = await showMTConfirm(
      context,
      title: l.transcriptsDeleteTitle,
      message: l.desktopTranscriptsDeleteBody,
      confirmLabel: l.transcriptsDeleteAll,
      cancelLabel: l.cancel,
      destructive: true,
    );
    if (!sure) return;
    await ref.read(transcriptStoreProvider)?.clear();
    ref
      ..invalidate(transcriptIndexProvider)
      ..invalidate(transcriptForProvider)
      ..invalidate(transcriptsSummaryProvider);
  }
}
