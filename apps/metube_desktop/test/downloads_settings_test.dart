import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/addresses_data.dart';
import 'package:metube_desktop/data/setup_data.dart';
import 'package:metube_desktop/data/downloads_data.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/local_copies.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/features/downloads/downloads_panel.dart';
import 'package:metube_desktop/features/settings/folders_pane.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

class _Folders extends NoFolders {
  const _Folders();

  @override
  Future<String?> videos() async => r'C:\Users\me\Videos';

  @override
  Future<String?> downloads() async => r'C:\Users\me\Downloads';
}

const _reel = 'https://www.instagram.com/reel/abc/';

void main() {
  Future<ShellHarness> open(
    WidgetTester tester, {
    String? to,
    List<LibraryItem> library = const [],
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
      library: library,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      overrides: [desktopFoldersProvider.overrideWithValue(const _Folders())],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    if (to != null) {
      GoRouter.of(tester.element(find.byType(EmberSidebar))).go(to);
      await tester.pumpAndSettle();
    }
    return h;
  }

  group('the downloads button and panel', () {
    testWidgets('counts what is under way, and the panel lets one go', (
      tester,
    ) async {
      final h = await open(tester);
      final task = h.engine.submit(_reel, Quality.best);
      await tester.pumpAndSettle();
      expect(byLabel('Downloads · 1 download in progress'), findsOneWidget);

      await tester.tap(byLabel('Downloads · 1 download in progress'));
      await tester.pumpAndSettle();
      final panel = find.byType(DownloadsPanel);
      expect(
        // The section, and the clip's own line.
        find.descendant(of: panel, matching: find.text('Waiting')),
        findsNWidgets(2),
      );
      await tester.tap(find.descendant(of: panel, matching: byLabel('Cancel')));
      await tester.pumpAndSettle();
      expect(h.engine.cancelled, [task.id]);
    });

    testWidgets('a failed clip is tried again from the panel', (tester) async {
      final h = await open(tester);
      final task = h.engine.submit(_reel, Quality.best);
      h.engine.fail(task, const NetworkException('dropped'));
      await tester.pumpAndSettle();
      await tester.tap(byLabel('Downloads'));
      await tester.pumpAndSettle();
      expect(find.text('Needs your attention'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(h.engine.submitted, hasLength(2));
      expect(h.engine.forgotten, [task.id]);
    });

    testWidgets('empty, it says how downloads begin, and offers nothing to '
        'hide even after the server finished a clip', (tester) async {
      final h = await open(tester);
      h.engine.finish(h.engine.submit(_reel, Quality.best));
      await tester.pumpAndSettle();
      await tester.tap(byLabel('Downloads'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing is downloading'), findsOneWidget);
      expect(find.text('Hide finished'), findsNothing);
    });
  });

  testWidgets('a clip on the server offers an offline copy and a download', (
    tester,
  ) async {
    await open(
      tester,
      to: '/item/${Uri.encodeComponent(_reel)}',
      library: const [
        LibraryItem(
          canonicalUrl: _reel,
          title: 'A reel',
          onServer: true,
          serverFilename: 'Kids/abc.mp4',
        ),
      ],
    );
    expect(find.text('Make available offline'), findsOneWidget);
    expect(find.text('Download…'), findsOneWidget);
  });

  testWidgets('"then download it to this computer" marks the clip sent', (
    tester,
  ) async {
    final h = await open(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(EmberSidebar),
        matching: find.text('Add link'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, _reel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Then download it to this computer'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Start download'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmberSidebar)),
    );
    expect(container.read(pullAfterProvider), {
      h.engine.submitted.single.id: null,
    });
  });

  group('settings', () {
    testWidgets('the folders pane shows the default folders and the rules', (
      tester,
    ) async {
      await open(tester, to: '/settings/folders');
      expect(find.byType(FoldersPane), findsOneWidget);
      expect(find.text(r'C:\Users\me\Videos\MeTube\Offline'), findsOneWidget);
      expect(find.text(r'C:\Users\me\Downloads\MeTube'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      // The download folder now reads "ask me every time", beside the
      // switch's own name.
      expect(find.text('Ask me every time'), findsNWidgets(2));
      expect(find.text(r'C:\Users\me\Downloads\MeTube'), findsNothing);
    });

    testWidgets('a section not built yet says so instead of an empty page', (
      tester,
    ) async {
      await open(tester, to: '/settings/backup');
      expect(find.textContaining('later step'), findsOneWidget);
    });
  });

  group('**the guard**: the address is chosen by hand', () {
    ProviderContainer make(MemoryKeyValueStore store) {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          initialServerSetupProvider.overrideWithValue(
            ServerConfig(
              baseUrl: 'http://192.168.1.10:8081',
              username: 'me',
              password: 'secret',
            ),
          ),
          initialAddressesProvider.overrideWithValue(
            const ServerAddresses(
              urls: ['http://192.168.1.10:8081', 'https://tunnel.example.com'],
            ),
          ),
          // The home address is down and the tunnel answers: the phone
          // would switch; this app must not.
          endpointResolverProvider.overrideWithValue(
            EndpointResolver(
              probe: (url) async => url.contains('tunnel')
                  ? MTEndpointStatus.ok
                  : MTEndpointStatus.unreachable,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('an address that stops answering is not swapped for one that '
        'answers; "Use" swaps, keeping the account', () async {
      final store = MemoryKeyValueStore();
      final c = make(store);
      final statuses = await c.read(addressStatusesProvider.future);
      expect(statuses['https://tunnel.example.com'], MTEndpointStatus.ok);
      expect(c.read(serverConfigProvider)!.baseUrl, 'http://192.168.1.10:8081');

      await c
          .read(addressesProvider.notifier)
          .use('https://tunnel.example.com');
      final config = c.read(serverConfigProvider)!;
      expect(config.baseUrl, 'https://tunnel.example.com');
      expect(config.password, 'secret');
      expect(
        (await AddressesStore(store: store, mutex: PrefsMutex()).read()).active,
        'https://tunnel.example.com',
      );
    });

    test('an address is added once, cleaned; the one in use cannot be '
        'removed', () async {
      final c = make(MemoryKeyValueStore());
      final addresses = c.read(addressesProvider.notifier);
      expect(await addresses.add(' https://new.example.com/ '), isTrue);
      expect(await addresses.add('https://new.example.com'), isFalse);
      expect(await addresses.add('not an address'), isFalse);
      await addresses.remove('http://192.168.1.10:8081');
      expect(c.read(addressesProvider).urls, [
        'http://192.168.1.10:8081',
        'https://tunnel.example.com',
        'https://new.example.com',
      ]);
    });
  });

  test('the copies count toward the downloads badge', () {
    final c = ProviderContainer(
      overrides: [
        localCopiesProvider.overrideWith(_TwoCopies.new),
        downloadEngineProvider.overrideWithValue(null),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(activeDownloadsProvider), 1);
  });
}

class _TwoCopies extends LocalCopies {
  @override
  List<LocalCopy> build() => const [
    LocalCopy(
      id: 'a',
      kind: CopyKind.offline,
      canonicalUrl: _reel,
      title: 'A reel',
      serverPath: 'abc.mp4',
      folder: 'C:',
    ),
    LocalCopy(
      id: 'b',
      kind: CopyKind.download,
      canonicalUrl: _reel,
      title: 'A reel',
      serverPath: 'abc.mp4',
      folder: 'C:',
      phase: CopyPhase.done,
    ),
  ];
}
