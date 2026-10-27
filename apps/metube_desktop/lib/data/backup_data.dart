import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import '../di.dart';
import 'folders_data.dart';
import 'library_data.dart';
import 'lists_data.dart';
import 'setup_data.dart';
import 'transcripts_data.dart';

/// Where the dated backups of this computer are kept:
/// `%APPDATA%\MeTube Ember\backup`. Overridden in main; null (tests) keeps
/// none.
final backupFolderProvider = Provider<Directory?>((ref) => null);

/// The server addresses the last imported phone backup named, offered by
/// the first-run setup and never written over an address already set.
final setupHintProvider = StateProvider<List<String>>((ref) => const []);

/// What a dropped or chosen file did.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// A phone backup, merged as a union: nothing here is dropped.
class MergedBackup extends ImportOutcome {
  const MergedBackup(this.result);
  final MergeResult result;
}

/// A transcripts file: those this computer lacked, or had older.
class MergedTranscripts extends ImportOutcome {
  const MergedTranscripts(this.added);
  final int added;
}

/// Neither: a file this app cannot read.
class NotABackup extends ImportOutcome {
  const NotABackup();
}

final backupsProvider = Provider<EmberBackups>(EmberBackups.new);

/// One dated copy at each start (the rotation skips it when nothing
/// changed, and keeps one an hour): the phone backs up on every change,
/// a computer left open for days at least every launch. Watched by the
/// shell.
final startupBackupProvider = FutureProvider<void>(
  (ref) => ref.read(backupsProvider).backUpNow().then((_) {}, onError: (_) {}),
);

/// This computer's backups (the phone's own format and rotation: the last
/// seven, an hour apart), importing a phone's, and exporting for it.
class EmberBackups {
  EmberBackups(this._ref);

  final Ref _ref;

  BackupRotation? get _rotation => switch (_ref.read(backupFolderProvider)) {
    final dir? => BackupRotation(directory: dir.path, prefix: 'metube_ember'),
    null => null,
  };

  BackupService get _service => BackupService(
    store: _ref.read(keyValueStoreProvider),
    secrets: _ref.read(secretStoreProvider),
    mutex: _ref.read(prefsMutexProvider),
    variant: 'ember',
  );

  /// A dated copy of everything here, skipped when nothing changed since
  /// the last; the oldest beyond seven go.
  Future<BackupFile?> backUpNow() async =>
      _rotation?.write(await _service.exportToString());

  Future<List<BackupFile>> list() async => await _rotation?.list() ?? const [];

  /// **Makes this computer what [file] says**, as a restore does on the
  /// phone: for this computer's own backups.
  Future<void> restore(BackupFile file) async {
    await _service.importFromString(await File(file.path).readAsString());
    _refresh();
  }

  /// A file from a phone, dropped or chosen: a backup is **added** to what
  /// is here (a union, the later change winning), a transcripts file adds
  /// what this computer lacked.
  Future<ImportOutcome> importFile(String contents) async {
    if (BackupMerge.looksLikeBackup(contents)) {
      final result = await BackupMerge(
        store: _ref.read(keyValueStoreProvider),
        mutex: _ref.read(prefsMutexProvider),
      ).mergeFrom(contents);
      _ref.read(setupHintProvider.notifier).state = result.serverAddresses;
      _refresh();
      return MergedBackup(result);
    }
    final transcripts = TranscriptBundle.decode(contents);
    final store = _ref.read(transcriptStoreProvider);
    if (transcripts == null || store == null) return const NotABackup();
    var added = 0;
    for (final t in transcripts) {
      final mine = await store.read(t.canonicalUrl, t.language);
      if (mine != null && !t.fetchedAt.isAfter(mine.fetchedAt)) continue;
      await keepTranscript(_ref, store, t);
      added++;
    }
    return MergedTranscripts(added);
  }

  /// Writes the two files a phone takes (this computer's tags, playlists
  /// and positions as a backup, and its transcripts) into
  /// `Downloads\MeTube\For the phone`, and returns that folder.
  Future<String?> exportForPhone({DateTime? at}) async {
    final base = await _ref.read(downloadFolderProvider.future);
    if (base == null) return null;
    final now = at ?? DateTime.now();
    final stamp = BackupRotation.stampOf(now);
    final dir = Directory('$base\\For the phone');
    await dir.create(recursive: true);
    await File('${dir.path}\\metube_ember_$stamp.json').writeAsString(
      await BackupMerge.exportShared(
        _ref.read(keyValueStoreProvider),
        now: now,
      ),
    );
    if (_ref.read(transcriptStoreProvider) case final store?) {
      final all = await store.readAll().toList();
      if (all.isNotEmpty) {
        await File('${dir.path}\\transcripts_$stamp.json')
            .writeAsString(TranscriptBundle.encode(all));
      }
    }
    return dir.path;
  }

  void _refresh() {
    _ref
      ..invalidate(libraryItemsProvider)
      ..invalidate(playlistsProvider)
      ..invalidate(tagCountsProvider);
  }
}
