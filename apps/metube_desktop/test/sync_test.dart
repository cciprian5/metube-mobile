import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/backup_data.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/lists_data.dart';
import 'package:metube_desktop/data/sync_data.dart';
import 'package:metube_desktop/data/transcripts_data.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import 'support/shell_harness.dart';

const _trip = 'https://www.youtube.com/watch?v=trip0000000';
const _phone = 'phone-a1b2';

/// A provider's own ref, for the helpers that take one.
final _refProvider = Provider<Ref>((ref) => ref);

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

/// A phone that already wrote its file: one tag on the trip, one list.
Future<void> _phoneWrote(
  SyncFolder folder, {
  Duration ago = Duration.zero,
}) async {
  final store = MemoryKeyValueStore();
  final mutex = PrefsMutex();
  final now = DateTime.now().subtract(ago);
  await TagsIndex(
    store: store,
    mutex: mutex,
    clock: () => now,
  ).toggleTag(_trip, 'travel');
  await PlaylistsStore(store: store, mutex: mutex, clock: () => now).create(
    'Evening',
    items: const [PlaylistEntry(canonicalUrl: _trip, cachedTitle: 'Trip')],
  );
  final mine = await SyncLocal(store: store, mutex: mutex).read(
    deviceId: _phone,
    deviceKind: 'phone',
    writtenAt: now.millisecondsSinceEpoch,
  );
  await folder.write(mine);
}

void main() {
  late Directory root;
  late SyncFolder folder;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ember_sync_');
    folder = SyncFolder.at('${root.path}/Sync');
  });
  tearDown(() => root.deleteSync(recursive: true));

  group('a run', () {
    late ProviderContainer c;
    late MemoryKeyValueStore store;
    late TranscriptStore transcripts;

    setUp(() async {
      store = MemoryKeyValueStore();
      transcripts = TranscriptStore(Directory('${root.path}/transcripts'));
      c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          transcriptStoreProvider.overrideWithValue(transcripts),
          loggerProvider.overrideWithValue(
            MTLogger(filePath: '${root.path}/log.txt'),
          ),
          backupFolderProvider.overrideWithValue(
            Directory('${root.path}/backup'),
          ),
        ],
      );
      await c.read(syncSettingsProvider.notifier).choose('${root.path}/Sync');
    });
    tearDown(() => c.dispose());

    test("**the guard**: the phone's tags and lists arrive, and this "
        'computer writes its own file beside them', () async {
      await _phoneWrote(folder);
      await c.read(tagsIndexProvider).toggleTag(_trip, 'nature');
      await c.read(emberSyncProvider).run();

      expect((await c.read(tagsIndexProvider).tagsOf(_trip)).toSet(), {
        'travel',
        'nature',
      });
      final lists = await c.read(playlistsProvider.future);
      expect(lists.single.name, 'Evening');
      final id = c.read(syncSettingsProvider).value!.deviceId!;
      expect(id, startsWith('ember-'));
      final written = await folder.read(id);
      expect(written!.tags[_trip]!.keys, containsAll(['travel', 'nature']));
      expect(c.read(syncReportProvider)!.devices.single.id, _phone);
    });

    test('**the guard**: a transcript this computer fetched is published; '
        "one imported from a phone's file is not", () async {
      await c.read(emberSyncProvider).run();
      final id = c.read(syncSettingsProvider).value!.deviceId!;
      final ref = c.read(_refProvider);
      await keepTranscript(
        ref,
        transcripts,
        _said('fetched0000'),
        fetched: true,
      );
      await keepTranscript(ref, transcripts, _said('imported000'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final published = Directory(
        '${root.path}/Sync/MeTube Sync/$id/transcripts',
      ).listSync().whereType<File>().toList();
      expect(published, hasLength(1));
      expect(await published.single.readAsString(), contains('fetched0000'));
    });

    test('**the guard**: choosing a folder forgets the last merge with the '
        'old one, so it is not read as an absence', () async {
      await store.setInt(SyncSettingsNotifier.lastKey, 1);
      await c.read(syncSettingsProvider.notifier).choose('${root.path}/Two');
      expect(await store.getInt(SyncSettingsNotifier.lastKey), isNull);
    });

    test('**the guard**: a file a day old is written again though nothing '
        'changed, so the others do not take this computer for gone', () async {
      await c.read(emberSyncProvider).run();
      final id = c.read(syncSettingsProvider).value!.deviceId!;
      final old = DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;
      await folder.write((await folder.read(id))!.copyWith(writtenAt: old));
      await c.read(emberSyncProvider).run();
      expect((await folder.read(id))!.writtenAt, greaterThan(old));
    });

    test('**the guard**: the seven dated backups are not touched by a '
        'run, so a sync gone wrong can still be undone', () async {
      final backups = Directory('${root.path}/backup')..createSync();
      for (var i = 1; i <= 7; i++) {
        File('${backups.path}/metube_ember_2026-10-0${i}_120000.json')
            .writeAsStringSync('{"day":$i}');
      }
      String state() =>
          (backups
                  .listSync()
                  .whereType<File>()
                  .map(
                    (f) => '${f.uri.pathSegments.last}=${f.readAsStringSync()}',
                  )
                  .toList()
                ..sort())
              .join(';');
      final before = state();
      await _phoneWrote(folder);
      await c.read(emberSyncProvider).run();
      expect(state(), before);
    });

    test('turned off, nothing is read or written', () async {
      await _phoneWrote(folder);
      await c.read(syncSettingsProvider.notifier).turnOff();
      await c.read(emberSyncProvider).run();
      expect(await c.read(tagsIndexProvider).tagsOf(_trip), isEmpty);
    });
  });

  group('the settings pane', () {
    Future<ShellHarness> open(
      WidgetTester tester, {
      Duration phoneAgo = Duration.zero,
    }) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final h = ShellHarness(
        library: const [],
        overrides: [
          loggerProvider.overrideWithValue(
            MTLogger(filePath: '${root.path}/log.txt'),
          ),
        ],
      );
      await h.store.setString(
        SyncSettingsNotifier.folderKey,
        '${root.path}/Sync',
      );
      await h.store.setString(SyncSettingsNotifier.deviceKey, 'ember-c3d4');
      await tester.runAsync(() => _phoneWrote(folder, ago: phoneAgo));
      await tester.pumpWidget(h.app());
      await settle(tester);
      GoRouter.of(tester.element(find.byType(EmberSidebar)))
          .go('/settings/sync');
      await settle(tester);
      return h;
    }

    testWidgets('**the guard**: the pane says which apps keep the folder in '
        'step, the phone on Wi-Fi only, and that sync is not a backup', (
      tester,
    ) async {
      await open(tester);
      expect(find.textContaining('FolderSync'), findsOneWidget);
      expect(find.textContaining('Wi‑Fi only'), findsOneWidget);
      expect(find.textContaining('not a backup'), findsOneWidget);
    });

    // The owner's report, 2026-11-05: the sync app on the phone had been
    // put to sleep and nothing said why the phone's changes stopped.
    testWidgets('**the guard**: a phone unheard for days says a sync app '
        'may be asleep; one heard today says nothing', (tester) async {
      await open(tester, phoneAgo: const Duration(days: 3));
      expect(find.textContaining('paused or asleep'), findsOneWidget);
    });

    testWidgets('a phone heard today has no note', (tester) async {
      await open(tester);
      expect(find.textContaining('paused or asleep'), findsNothing);
    });

    testWidgets('shows this computer and the phone, and forgetting the '
        'phone removes its folder', (tester) async {
      await open(tester);
      expect(find.text('This computer: Computer c3d4'), findsOneWidget);
      expect(find.textContaining('Last from Phone a1b2'), findsOneWidget);
      await tester.tap(find.text('Forget this device').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget this device').last);
      await settle(tester);
      expect(
        Directory('${root.path}/Sync/MeTube Sync/$_phone').existsSync(),
        isFalse,
      );
      // The pane re-reads the folder on the real clock; on a busy machine
      // that outlasts one settle, so give it a few before judging.
      final none = find.textContaining('No other device');
      for (var i = 0; i < 10 && none.evaluate().isEmpty; i++) {
        await settle(tester);
      }
      expect(none, findsOneWidget);
    });
  });
}

/// Lets real file work finish; each step resumes on the test's clock and
/// starts the next on the real one, so the two take turns.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
}
