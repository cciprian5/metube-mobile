import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../playlists/playlists_providers.dart';
import '../transcripts/transcripts_state.dart';
import 'sync_tree.dart';

/// Where this phone syncs and its name there. **Off until a folder is
/// chosen**; the name is made on the first choice and kept, so choosing
/// the folder again is the same device, not a new one.
class PhoneSyncSettings {
  const PhoneSyncSettings({this.tree, this.deviceId});

  final String? tree;
  final String? deviceId;

  bool get on => tree != null && deviceId != null;
}

/// The picker, and how a granted folder is reached; tests put a plain
/// folder on disk in their place.
final syncTreePickerProvider = Provider((ref) => const SyncTreePicker());
final syncStorageProvider = Provider<SyncStorage Function(String tree)>(
  (ref) => SafSyncStorage.new,
);

final phoneSyncSettingsProvider =
    AsyncNotifierProvider<PhoneSyncSettingsNotifier, PhoneSyncSettings>(
      PhoneSyncSettingsNotifier.new,
    );

class PhoneSyncSettingsNotifier extends AsyncNotifier<PhoneSyncSettings> {
  static const treeKey = 'sync_tree';
  static const deviceKey = 'sync_device';

  /// When this phone last merged with the folder: one that comes back after
  /// the others forgot what they deleted takes their data first.
  static const lastKey = 'sync_last';

  /// Whether the transcripts held before sync was turned on were published.
  static const publishedKey = 'sync_published';

  @override
  Future<PhoneSyncSettings> build() async {
    final store = ref.read(keyValueStoreProvider);
    return PhoneSyncSettings(
      tree: await store.getString(treeKey),
      deviceId: await store.getString(deviceKey),
    );
  }

  /// The system picker; false when it was closed without a folder.
  Future<bool> choose() async {
    final tree = await ref.read(syncTreePickerProvider).pick();
    if (tree == null) return false;
    await use(tree);
    return true;
  }

  Future<void> use(String tree) async {
    final store = ref.read(keyValueStoreProvider);
    final id = (await future).deviceId ?? SyncFolder.newDeviceId('phone');
    await ref.read(prefsMutexProvider).run(() async {
      await store.setString(deviceKey, id);
      await store.setString(treeKey, tree);
    });
    state = AsyncData(PhoneSyncSettings(tree: tree, deviceId: id));
  }

  /// Stops syncing. What is in the folder stays for the other devices.
  Future<void> turnOff() async {
    final store = ref.read(keyValueStoreProvider);
    await ref.read(prefsMutexProvider).run(() => store.remove(treeKey));
    state = AsyncData(PhoneSyncSettings(deviceId: (await future).deviceId));
  }
}

/// What the last run found, for the settings line.
class PhoneSyncReport {
  const PhoneSyncReport({
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

final phoneSyncReportProvider = StateProvider<PhoneSyncReport?>((ref) => null);

final phoneSyncProvider = Provider((ref) {
  final sync = PhoneSync(ref);
  // A pending write must not fire once what it would read is gone.
  ref.onDispose(sync.dispose);
  return sync;
});

/// **One run of the sync**: read the other devices' files, merge them into
/// this phone, write its own file, and trade transcripts.
class PhoneSync {
  PhoneSync(this._ref);

  final Ref _ref;
  String? _written;
  Future<void>? _running;
  Timer? _soon;

  SyncLocal get _local => SyncLocal(
    store: _ref.read(keyValueStoreProvider),
    mutex: _ref.read(prefsMutexProvider),
  );

  SyncFolder? _folder(PhoneSyncSettings s) =>
      s.on ? SyncFolder(_ref.read(syncStorageProvider)(s.tree!)) : null;

  void dispose() => _soon?.cancel();

  /// Whether a run waits on [nudge]'s pause.
  @visibleForTesting
  bool get waiting => _soon?.isActive ?? false;

  /// A change here: written after a short pause, so a burst of tag taps is
  /// one write. Nothing at all while sync is off, not even a timer.
  void nudge() {
    if (_ref.read(phoneSyncSettingsProvider).valueOrNull?.on != true) return;
    _soon?.cancel();
    _soon = Timer(const Duration(seconds: 5), () => unawaited(run()));
  }

  /// Never two at once: one asked for during another waits, then runs, so
  /// it reads the folder as it is now.
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
    final settings = await _ref.read(phoneSyncSettingsProvider.future);
    final folder = _folder(settings);
    if (folder == null) return;
    final store = _ref.read(keyValueStoreProvider);
    final now = DateTime.now();
    final myId = settings.deviceId!;
    try {
      final others = await folder.others(myId);
      final outcome = SyncMerge.forDevice(
        mine: await _local.read(deviceId: myId, deviceKind: 'phone'),
        others: [for (final d in others) d.snapshot],
        now: now.millisecondsSinceEpoch,
        lastSync: await store.getInt(PhoneSyncSettingsNotifier.lastKey),
      );
      if (await _local.apply(outcome.snapshot)) _refresh();
      final data = outcome.snapshot.encode();
      if (data != _written || await folder.read(myId) == null) {
        await folder.write(
          outcome.snapshot.copyWith(writtenAt: now.millisecondsSinceEpoch),
        );
        _written = data;
      }
      await _transcripts(folder, myId, others);
      await store.setInt(
        PhoneSyncSettingsNotifier.lastKey,
        now.millisecondsSinceEpoch,
      );
      _report(
        PhoneSyncReport(at: now, devices: others, cameBack: outcome.cameBack),
      );
    } on Object catch (e) {
      // A folder moved or its permission taken back: said on the settings
      // line, never a crash.
      if (e is! PlatformException && e is! SyncStorageException) rethrow;
      unawaited(_ref.read(loggerProvider).log('sync failed: $e', tag: 'sync'));
      _report(PhoneSyncReport(at: now, failed: true));
    }
  }

  Future<void> _transcripts(
    SyncFolder folder,
    String myId,
    List<SyncDevice> others,
  ) async {
    final sync = SyncTranscripts(
      folder: folder,
      myId: myId,
      local: await _ref.read(transcriptStoreProvider.future),
    );
    final store = _ref.read(keyValueStoreProvider);
    if (await store.getBool(PhoneSyncSettingsNotifier.publishedKey) != true) {
      await sync.publishMissing(others);
      await store.setBool(PhoneSyncSettingsNotifier.publishedKey, true);
    }
    final added = await sync.collect(others);
    if (added.isEmpty) return;
    final index = await _ref.read(transcriptIndexProvider.future);
    added.forEach(index.add);
    _ref.read(transcriptsRevisionProvider.notifier).state++;
  }

  /// A transcript this phone fetched, put where the others find it.
  Future<void> publish(Transcript transcript) async {
    final settings = _ref.read(phoneSyncSettingsProvider).valueOrNull;
    final folder = settings == null ? null : _folder(settings);
    if (folder == null) return;
    try {
      await SyncTranscripts(
        folder: folder,
        myId: settings!.deviceId!,
      ).publish(transcript);
    } on Object catch (e) {
      if (e is! PlatformException && e is! SyncStorageException) rethrow;
      // The next run publishes what is missing anyway.
    }
  }

  /// **"Forget this device"**: its transcripts move to this phone's folder,
  /// then its folder goes.
  Future<void> forget(SyncDevice device) async {
    final settings = await _ref.read(phoneSyncSettingsProvider.future);
    final folder = _folder(settings);
    if (folder == null) return;
    await SyncTranscripts(
      folder: folder,
      myId: settings.deviceId!,
    ).adopt(device.id);
    await run();
  }

  void _report(PhoneSyncReport report) =>
      _ref.read(phoneSyncReportProvider.notifier).state = report;

  void _refresh() => _ref
    ..invalidate(libraryItemsProvider)
    ..invalidate(playlistsProvider)
    ..invalidate(tagCountsProvider);
}

/// **When the phone syncs**, for the life of the app: on opening, on coming
/// back to it (the computer may have changed something meanwhile), and on
/// leaving it, so the last position and tags are written before Android
/// may stop the app. A change made inside the app nudges a run too
/// ([PhoneSync.nudge]).
final phoneSyncRunnerProvider = Provider<void>((ref) {
  final settings = ref.watch(phoneSyncSettingsProvider).valueOrNull;
  if (settings == null || !settings.on) return;
  final sync = ref.read(phoneSyncProvider);
  unawaited(sync.run());
  final listener = AppLifecycleListener(
    onResume: () => unawaited(sync.run()),
    onPause: () => unawaited(sync.run()),
  );
  ref.onDispose(listener.dispose);
});
