import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/backup_data.dart';
import '../../data/folders_data.dart';

/// Whether dropped or pasted [text] is a phone's backup or transcripts
/// file, which goes to the import rather than the add dialog.
bool isBackupText(String text) =>
    BackupMerge.looksLikeBackup(text) || TranscriptBundle.decode(text) != null;

/// Adds a phone's file to this computer and says what it brought.
Future<ImportOutcome> importFromPhone(
  BuildContext context,
  WidgetRef ref,
  String contents,
) async {
  final outcome = await ref.read(backupsProvider).importFile(contents);
  if (!context.mounted) return outcome;
  final l = context.mtl;
  final (message, kind) = switch (outcome) {
    MergedBackup(:final result) when result.changedNothing => (
      l.desktopImportedNothing,
      MTNoticeKind.info,
    ),
    MergedBackup(:final result) => (
      l.desktopImportedBackup(
        result.tagged,
        result.playlists,
        result.positions,
      ),
      MTNoticeKind.done,
    ),
    MergedTranscripts(:final added) => (
      l.desktopImportedTranscripts(added),
      MTNoticeKind.done,
    ),
    NotABackup() => (l.desktopNotABackup, MTNoticeKind.failed),
  };
  showMTNotice(context, message: message, kind: kind);
  return outcome;
}

/// Windows' open dialog for a phone's file, then [importFromPhone].
Future<ImportOutcome?> chooseAndImport(
  BuildContext context,
  WidgetRef ref,
) async {
  final text = await ref
      .read(desktopFoldersProvider)
      .openText(extensions: const ['json']);
  if (text == null || !context.mounted) return null;
  return importFromPhone(context, ref, text);
}
