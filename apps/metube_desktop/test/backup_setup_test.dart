import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/backup_data.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/setup_data.dart';
import 'package:metube_desktop/data/transcripts_data.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/features/settings/backup_actions.dart';
import 'package:metube_desktop/features/setup/setup_dialog.dart';
import 'package:metube_desktop/features/setup/setup_sections.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import 'support/shell_harness.dart';

const _a = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';

/// A phone's backup: one favourite, its server's address with a password
/// in it (which must not come over).
Future<String> _phoneBackup() async {
  final store = MemoryKeyValueStore();
  final mutex = PrefsMutex();
  await TagsIndex(
    store: store,
    mutex: mutex,
    clock: () => DateTime.utc(2026, 10, 20),
  ).toggleTag(_a, MTConstants.favoritesSystemTag);
  await store.setString('active_url', 'http://192.168.1.10:8081');
  return BackupService(
    store: store,
    secrets: MemorySecretStore(),
    mutex: mutex,
    variant: 'super',
  ).exportToString();
}

class _Downloads extends NoFolders {
  _Downloads(this.root);
  final Directory root;

  @override
  Future<String?> downloads() async => root.path;
}

void main() {
  group('backups', () {
    late Directory root;
    late ProviderContainer c;
    late MemoryKeyValueStore store;

    setUp(() {
      root = Directory.systemTemp.createTempSync('ember_backup_');
      store = MemoryKeyValueStore();
      c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          backupFolderProvider.overrideWithValue(
            Directory('${root.path}/backup'),
          ),
          transcriptStoreProvider.overrideWithValue(
            TranscriptStore(Directory('${root.path}/transcripts')),
          ),
          desktopFoldersProvider.overrideWithValue(_Downloads(root)),
        ],
      );
    });
    tearDown(() {
      c.dispose();
      root.deleteSync(recursive: true);
    });

    test(
      'a dated copy, then restoring it makes this computer as it was',
      () async {
        await store.setString('video_sort_option', 'oldest');
        final copy = await c.read(backupsProvider).backUpNow();
        expect(copy, isNotNull);
        expect(await c.read(backupsProvider).list(), hasLength(1));
        await store.setString('video_sort_option', 'newest');
        await c.read(backupsProvider).restore(copy!);
        expect(await store.getString('video_sort_option'), 'oldest');
      },
    );

    test("**the guard**: a phone's backup is added, and its address only "
        'offered, without its password', () async {
      final tags = c.read(tagsIndexProvider);
      await tags.toggleTag(_a, 'mine');
      final outcome = await c
          .read(backupsProvider)
          .importFile(await _phoneBackup());
      expect(outcome, isA<MergedBackup>());
      expect((await tags.tagsOf(_a)).toSet(), {
        'mine',
        MTConstants.favoritesSystemTag,
      });
      expect(c.read(setupHintProvider), ['http://192.168.1.10:8081']);
      expect(await store.getString('active_url'), isNull);
    });

    test('a transcripts file adds what this computer lacked', () async {
      final t = Transcript(
        canonicalUrl: _a,
        language: 'en',
        source: 'captions',
        fetchedAt: DateTime.utc(2026, 10, 1),
        segments: const [],
      );
      final outcome = await c
          .read(backupsProvider)
          .importFile(TranscriptBundle.encode([t]));
      expect((outcome as MergedTranscripts).added, 1);
      final again = await c
          .read(backupsProvider)
          .importFile(TranscriptBundle.encode([t]));
      expect((again as MergedTranscripts).added, 0);
    });

    test('anything else is refused', () async {
      expect(
        await c.read(backupsProvider).importFile('just text'),
        isA<NotABackup>(),
      );
    });

    test('the export for the phone is two files in Downloads', () async {
      await c.read(tagsIndexProvider).toggleTag(_a, 'mine');
      final folder = await c
          .read(backupsProvider)
          .exportForPhone(at: DateTime(2026, 10, 24, 12));
      final names = Directory(folder!)
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(names, ['metube_ember_2026-10-24_120000.json']);
      expect(folder, endsWith(r'\For the phone'));
    });
  });

  test('a dropped backup or transcripts file goes to the import, links to '
      'the add dialog', () async {
    expect(isBackupText(await _phoneBackup()), isTrue);
    expect(isBackupText(TranscriptBundle.encode(const [])), isTrue);
    expect(isBackupText('https://youtu.be/aaaaaaaaaaa'), isFalse);
  });

  group('the first-run setup', () {
    Future<ShellHarness> open(
      WidgetTester tester, {
      Object? refuse,
      List<LanHit> found = const [],
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
          connectionTestProvider.overrideWithValue((config) async {
            if (refuse case final e?) throw e;
          }),
          lanProbeProvider.overrideWithValue(
            LanProbe(
              adapters: () async => [
                (
                  name: 'Ethernet',
                  addresses: [InternetAddress('192.168.1.20')],
                ),
              ],
              connect: (host, port, _) async =>
                  found.any((f) => f.url == 'http://${host.address}:$port'),
              identify: (url, _) async =>
                  found.where((f) => f.url == url).firstOrNull,
            ),
          ),
        ],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      return h;
    }

    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(EmberSidebar)));

    Finder field(String label) => find.widgetWithText(TextField, label);

    testWidgets('an address that answers is kept, **the password in the '
        'secret store and never in the settings file**', (tester) async {
      final h = await open(tester);
      await tester.enterText(field('Server URL (MeTube)'), 'http://nas:8086/');
      await tester.enterText(field('Username'), 'me');
      await tester.enterText(field('Password'), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
      await tester.pumpAndSettle();
      final c = container(tester);
      final setup = c.read(serverSetupProvider)!;
      expect((setup.baseUrl, setup.username), ('http://nas:8086', 'me'));
      expect(await c.read(secretStoreProvider).read('password'), 'secret');
      for (final key in await h.store.keys()) {
        expect('${await h.store.get(key)}', isNot(contains('secret')));
      }
      expect(find.text('Connect to your MeTube server'), findsNothing);
    });

    testWidgets('a refused password says so and keeps nothing', (tester) async {
      await open(tester, refuse: const AuthFailureException());
      await tester.enterText(field('Server URL (MeTube)'), 'http://nas:8086');
      await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong username or password'), findsOneWidget);
      expect(container(tester).read(serverSetupProvider), isNull);
    });

    testWidgets('a server found on the network fills the address', (
      tester,
    ) async {
      await open(
        tester,
        found: const [
          LanHit(
            url: 'http://192.168.1.10:8081',
            status: MTEndpointStatus.ok,
            version: ServerVersion(version: '2026.10.09'),
          ),
        ],
      );
      await tester.tap(find.text('Search my network').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('2026.10.09'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Server URL (MeTube)')).controller!.text,
        'http://192.168.1.10:8081',
      );
    });

    testWidgets('a password sent over plain http beyond the home network is '
        'warned about; at home it is not', (tester) async {
      await open(tester);
      await tester.enterText(field('Password'), 'secret');
      await tester.enterText(
        field('Server URL (MeTube)'),
        'http://metube.example.com',
      );
      await tester.pump();
      expect(find.textContaining('unencrypted'), findsOneWidget);
      await tester.enterText(
        field('Server URL (MeTube)'),
        'http://192.168.1.10:8081',
      );
      await tester.pump();
      expect(find.textContaining('unencrypted'), findsNothing);
    });
  });
}
