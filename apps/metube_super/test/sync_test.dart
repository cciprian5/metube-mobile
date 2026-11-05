import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/playlists/playlists_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/sync/phone_sync.dart';
import 'package:metube_super/features/sync/sync_screen.dart';
import 'package:metube_super/features/sync/sync_tree.dart';
import 'package:metube_super/features/transcripts/transcripts_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

const _trip = 'https://www.youtube.com/watch?v=trip0000000';
const _tree =
    'content://com.android.externalstorage.documents/tree/primary%3ASync';
const _ember = 'ember-c3d4';

/// The system picker, answered with the folder the user would choose.
class _Picker extends SyncTreePicker {
  const _Picker();

  @override
  Future<String?> pick() async => _tree;
}

Transcript _said(String id) => Transcript(
  canonicalUrl: 'https://www.youtube.com/watch?v=$id',
  language: 'en',
  source: 'captions',
  fetchedAt: DateTime.utc(2026, 10, 25),
  segments: const [
    TranscriptSegment(
      start: Duration.zero,
      end: Duration(seconds: 2),
      text: 'hi',
    ),
  ],
);

void main() {
  late Directory root;
  late SyncFolder folder;

  setUp(() {
    root = Directory.systemTemp.createTempSync('super_sync_');
    folder = SyncFolder.at('${root.path}/Sync');
  });
  tearDown(() => root.deleteSync(recursive: true));

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${root.path}/log.txt'),
        ),
        syncTreePickerProvider.overrideWithValue(const _Picker()),
        // The granted folder, here a plain one on disk.
        syncStorageProvider.overrideWithValue(
          (tree) => IoSyncStorage('${root.path}/Sync'),
        ),
        transcriptsRootProvider.overrideWith(
          (ref) async => Directory('${root.path}/transcripts'),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// The computer already wrote its file: one tag on the trip, one list.
  Future<void> computerWrote() async {
    final store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    final now = DateTime.now();
    await TagsIndex(
      store: store,
      mutex: mutex,
      clock: () => now,
    ).toggleTag(_trip, 'nature');
    await PlaylistsStore(store: store, mutex: mutex, clock: () => now).create(
      'Evening',
      items: const [PlaylistEntry(canonicalUrl: _trip, cachedTitle: 'Trip')],
    );
    await folder.write(
      await SyncLocal(store: store, mutex: mutex).read(
        deviceId: _ember,
        deviceKind: 'ember',
        writtenAt: now.millisecondsSinceEpoch,
      ),
    );
  }

  test("**the guard**: the computer's tags and lists arrive on the phone, "
      'and the phone writes its own file beside them', () async {
    await computerWrote();
    final c = make();
    await c.read(tagsIndexProvider).toggleTag(_trip, 'travel');
    expect(await c.read(phoneSyncSettingsProvider.notifier).choose(), isTrue);
    await c.read(phoneSyncProvider).run();

    expect((await c.read(tagsIndexProvider).tagsOf(_trip)).toSet(), {
      'travel',
      'nature',
    });
    expect((await c.read(playlistsProvider.future)).single.name, 'Evening');
    final id = c.read(phoneSyncSettingsProvider).value!.deviceId!;
    expect(id, startsWith('phone-'));
    expect((await folder.read(id))!.tags[_trip]!.keys, contains('travel'));
    expect(c.read(phoneSyncReportProvider)!.devices.single.id, _ember);
  });

  test('**the guard**: a transcript this phone fetched is published; one '
      'imported from a file is not', () async {
    final c = make();
    await c.read(phoneSyncSettingsProvider.notifier).choose();
    await c.read(phoneSyncProvider).run();
    final id = c.read(phoneSyncSettingsProvider).value!.deviceId!;
    final service = c.read(transcriptsServiceProvider);
    await service.save(_said('fetched0000'), fetched: true);
    await service.importAll(TranscriptBundle.encode([_said('imported000')]));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final files = await folder.transcriptFiles(id);
    expect(files, hasLength(1));
    expect(
      await folder.readTranscript(id, files.single),
      contains('fetched0000'),
    );
  });

  test('**the guard**: choosing a folder forgets the last merge with the '
      'old one, so it is not read as an absence', () async {
    final c = make();
    final store = c.read(keyValueStoreProvider);
    await store.setInt(PhoneSyncSettingsNotifier.lastKey, 1);
    await c.read(phoneSyncSettingsProvider.notifier).choose();
    expect(await store.getInt(PhoneSyncSettingsNotifier.lastKey), isNull);
  });

  test('**the guard**: a file a day old is written again though nothing '
      'changed, so the others do not take this phone for gone', () async {
    final c = make();
    await c.read(phoneSyncSettingsProvider.notifier).choose();
    await c.read(phoneSyncProvider).run();
    final id = c.read(phoneSyncSettingsProvider).value!.deviceId!;
    final old = DateTime.now()
        .subtract(const Duration(days: 2))
        .millisecondsSinceEpoch;
    await folder.write((await folder.read(id))!.copyWith(writtenAt: old));
    await c.read(phoneSyncProvider).run();
    expect((await folder.read(id))!.writtenAt, greaterThan(old));
  });

  test('**the guard**: with sync off, a tag change starts no sync timer; '
      'with it on, one does', () async {
    final c = make();
    await c.read(tagsIndexProvider).toggleTag(_trip, 'travel');
    expect(c.read(phoneSyncProvider).waiting, isFalse);
    await c.read(phoneSyncSettingsProvider.notifier).choose();
    await c.read(tagsIndexProvider).toggleTag(_trip, 'calm');
    expect(c.read(phoneSyncProvider).waiting, isTrue);
  });

  testWidgets('**the guard**: a pending write is dropped when the app goes, '
      'not run against what is gone', (tester) async {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        syncTreePickerProvider.overrideWithValue(const _Picker()),
      ],
    );
    await c.read(phoneSyncSettingsProvider.notifier).choose();
    c.read(phoneSyncProvider).nudge();
    expect(c.read(phoneSyncProvider).waiting, isTrue);
    c.dispose();
    // Past the pause: a timer left behind would fire now and fail here.
    await tester.pump(const Duration(seconds: 6));
  });

  test('the folder shows as the user named it', () {
    expect(syncFolderName(_tree), 'Sync');
  });

  group('the screen', () {
    Widget host(ProviderContainer c, {Locale locale = const Locale('en')}) =>
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: mtTheme(MTVariant.superApp, Brightness.light),
            locale: locale,
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            home: const SyncScreen(),
          ),
        );

    ProviderContainer on({Duration heardAgo = Duration.zero}) {
      final c = make();
      final store = c.read(keyValueStoreProvider);
      store.setString(PhoneSyncSettingsNotifier.treeKey, _tree);
      store.setString(PhoneSyncSettingsNotifier.deviceKey, 'phone-a1b2');
      c.read(phoneSyncReportProvider.notifier).state = PhoneSyncReport(
        at: DateTime.now(),
        cameBack: true,
        devices: [
          SyncDevice(
            SyncSnapshot(
              deviceId: _ember,
              deviceKind: 'ember',
              writtenAt: DateTime.now()
                  .subtract(heardAgo)
                  .millisecondsSinceEpoch,
            ),
          ),
        ],
      );
      return c;
    }

    // The owner's report, 2026-11-05: the sync app on the phone had been
    // put to sleep and nothing said why the computer's changes stopped.
    testWidgets('**the guard**: a device unheard for days says a sync app '
        'may be asleep; one heard today says nothing', (tester) async {
      await tester.pumpWidget(host(on(heardAgo: const Duration(days: 3))));
      await tester.pumpAndSettle();
      expect(find.textContaining('paused or asleep'), findsOneWidget);

      await tester.pumpWidget(host(on()));
      await tester.pumpAndSettle();
      expect(find.textContaining('paused or asleep'), findsNothing);
    });

    testWidgets('the note fits, in Arabic too', (tester) async {
      await expectNoOverflow(
        tester,
        () => host(
          on(heardAgo: const Duration(days: 3)),
          locale: const Locale('ar'),
        ),
      );
    });

    testWidgets('on, with the computer, at every size', (tester) async {
      await expectNoOverflow(tester, () => host(on()));
    });

    testWidgets('and in Arabic', (tester) async {
      await expectNoOverflow(
        tester,
        () => host(on(), locale: const Locale('ar')),
      );
    });

    testWidgets('off, it says nothing leaves the phone', (tester) async {
      await tester.pumpWidget(host(make()));
      await tester.pumpAndSettle();
      expect(find.text('Off. Nothing leaves this phone.'), findsOneWidget);
      expect(find.text('Turn off'), findsNothing);
    });
  });
}
