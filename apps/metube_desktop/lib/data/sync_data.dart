import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import '../di.dart';
import 'library_data.dart';
import 'lists_data.dart';
import 'saved_searches.dart';
import 'transcripts_data.dart';

/// Where this computer syncs, and its name there. **Off until a folder is
/// chosen**; the name is made on the first choice and kept, so choosing the
/// folder again later is the same device, not a new one.
class SyncSettings {
  const SyncSettings({this.folder, this.deviceId});

  final String? folder;
  final String? deviceId;

  bool get on => folder != null && deviceId != null;
}

final syncSettingsProvider =
    AsyncNotifierProvider<SyncSettingsNotifier, SyncSettings>(
      SyncSettingsNotifier.new,
    );

class SyncSettingsNotifier extends AsyncNotifier<SyncSettings> {
  static const folderKey = 'ember_sync_folder';
  static const deviceKey = 'ember_sync_device';

  /// When this computer last merged with the folder, for the device that
  /// comes back after the removals were forgotten.
  static const lastKey = 'ember_sync_last';

  /// Whether the transcripts held before sync was turned on were published.
  static const publishedKey = 'ember_sync_published';

  @override
  Future<SyncSettings> build() async {
    final store = ref.read(keyValueStoreProvider);
    return SyncSettings(
      folder: await store.getString(folderKey),
      deviceId: await store.getString(deviceKey),
    );
  }

  Future<void> choose(String folder) async {
    final store = ref.read(keyValueStoreProvider);
    final id = (await future).deviceId ?? SyncFolder.newDeviceId('ember');
    await ref.read(prefsMutexProvider).run(() async {
      await store.setString(deviceKey, id);
      await store.setString(folderKey, folder);
      // A new folder starts a new history: the time of the last merge
      // with an old one would read as an absence and set data aside.
      await store.remove(lastKey);
    });
    state = AsyncData(SyncSettings(folder: folder, deviceId: id));
  }

  /// Stops syncing. What is in the folder stays for the other devices.
  Future<void> turnOff() async {
    final store = ref.read(keyValueStoreProvider);
    await ref.read(prefsMutexProvider).run(() => store.remove(folderKey));
    state = AsyncData(SyncSettings(deviceId: (await future).deviceId));
  }
}

/// What the last run found, for the settings line.
class SyncReport {
  const SyncReport({
    required this.at,
    this.devices = const [],
    this.cameBack = false,
    this.failed = false,
  });

  final DateTime at;
  final List<SyncDevice> devices;
  final bool cameBack;
  final bool failed;
}

final syncReportProvider = StateProvider<SyncReport?>((ref) => null);

final emberSyncProvider = Provider((ref) => EmberSync(ref));

/// **One run of the sync**: read the other devices' files, merge them into
/// this computer, write its own file, and trade transcripts.
class EmberSync {
  EmberSync(this._ref);

  final Ref _ref;

  /// The data last written to the folder, without its time, so a run that
  /// changed nothing writes nothing.
  String? _written;
  Future<void>? _running;

  SyncLocal get _local => SyncLocal(
    store: _ref.read(keyValueStoreProvider),
    mutex: _ref.read(prefsMutexProvider),
    searchesKey: SavedSearches.key,
  );

  /// This computer's data as the folder would see it, for spotting a local
  /// change without a full run.
  Future<String?> localPrint({bool withPositions = true}) async {
    final settings = _ref.read(syncSettingsProvider).valueOrNull;
    if (settings == null || !settings.on) return null;
    final mine = await _local.read(
      deviceId: settings.deviceId!,
      deviceKind: 'ember',
    );
    return (withPositions ? mine : mine.copyWith(positions: const {})).encode();
  }

  /// Runs, never two at once over the same files: one asked for while
  /// another is going waits for it, then runs itself, so it reads the folder
  /// as it is now (a device just forgotten, a file just arrived).
  Future<void> run() async {
    for (var going = _running; going != null; going = _running) {
      await going;
    }
    final mine = _run();
    _running = mine;
    try {
      await mine;
    } finally {
      if (identical(_running, mine)) _running = null;
    }
  }

  Future<void> _run() async {
    final settings = await _ref.read(syncSettingsProvider.future);
    if (!settings.on) return;
    final store = _ref.read(keyValueStoreProvider);
    final now = DateTime.now();
    try {
      final folder = SyncFolder.at(settings.folder!);
      final myId = settings.deviceId!;
      final others = await folder.others(myId);
      final outcome = SyncMerge.forDevice(
        mine: await _local.read(deviceId: myId, deviceKind: 'ember'),
        others: [for (final d in others) d.snapshot],
        now: now.millisecondsSinceEpoch,
        lastSync: await store.getInt(SyncSettingsNotifier.lastKey),
      );
      if (await _local.apply(outcome.snapshot)) _refresh();
      final data = outcome.snapshot.encode();
      // Written when it changed, and at least daily though it did not,
      // or the others would take a quiet device's file for a gone one.
      final own = await folder.read(myId);
      if (data != _written ||
          own == null ||
          now.millisecondsSinceEpoch - own.writtenAt >
              SyncMerge.heartbeat.inMilliseconds) {
        await folder.write(
          outcome.snapshot.copyWith(writtenAt: now.millisecondsSinceEpoch),
        );
        _written = data;
      }
      await _transcripts(folder, myId, others);
      await store.setInt(
        SyncSettingsNotifier.lastKey,
        now.millisecondsSinceEpoch,
      );
      _report(SyncReport(at: now, devices: others, cameBack: outcome.cameBack));
    } on FileSystemException catch (e) {
      unawaited(_ref.read(loggerProvider).log('sync failed: $e', tag: 'sync'));
      _report(SyncReport(at: now, failed: true));
    }
  }

  Future<void> _transcripts(
    SyncFolder folder,
    String myId,
    List<SyncDevice> others,
  ) async {
    final store = _ref.read(transcriptStoreProvider);
    if (store == null) return;
    final sync = SyncTranscripts(folder: folder, myId: myId, local: store);
    final keys = _ref.read(keyValueStoreProvider);
    if (await keys.getBool(SyncSettingsNotifier.publishedKey) != true) {
      await sync.publishMissing(others);
      await keys.setBool(SyncSettingsNotifier.publishedKey, true);
    }
    for (final transcript in await sync.collect(others)) {
      noteTranscript(_ref, transcript);
    }
  }

  /// A transcript this computer fetched, put where the others find it.
  Future<void> publish(Transcript transcript) async {
    final settings = _ref.read(syncSettingsProvider).valueOrNull;
    final store = _ref.read(transcriptStoreProvider);
    if (settings == null || !settings.on || store == null) return;
    try {
      await SyncTranscripts(
        folder: SyncFolder.at(settings.folder!),
        myId: settings.deviceId!,
        local: store,
      ).publish(transcript);
    } on FileSystemException {
      // The next run publishes what is missing anyway.
    }
  }

  /// **"Forget this device"**: its transcripts move to this computer's
  /// folder, then its folder goes. Used for a lost or sold phone.
  Future<void> forget(SyncDevice device) async {
    final settings = await _ref.read(syncSettingsProvider.future);
    if (!settings.on) return;
    await SyncTranscripts(
      folder: SyncFolder.at(settings.folder!),
      myId: settings.deviceId!,
    ).adopt(device.id);
    await run();
  }

  void _report(SyncReport report) =>
      _ref.read(syncReportProvider.notifier).state = report;

  void _refresh() => _ref
    ..invalidate(libraryItemsProvider)
    ..invalidate(playlistsProvider)
    ..invalidate(tagCountsProvider)
    ..invalidate(savedSearchesProvider);
}
