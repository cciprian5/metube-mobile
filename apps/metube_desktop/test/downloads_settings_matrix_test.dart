import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/addresses_data.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/data/local_copies.dart';
import 'package:metube_desktop/features/downloads/downloads_button.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';

import 'desktop_matrix.dart';
import 'support/shell_harness.dart';

class _Folders extends NoFolders {
  const _Folders();

  // Long on purpose: a OneDrive Videos folder with a long user name.
  @override
  Future<String?> videos() async =>
      r'C:\Users\a.very.long.user.name\OneDrive - Company Name\Videos';

  @override
  Future<String?> downloads() async => r'C:\Users\me\Downloads';
}

class _Copies extends LocalCopies {
  @override
  List<LocalCopy> build() => const [
    LocalCopy(
      id: 'a',
      kind: CopyKind.offline,
      canonicalUrl: 'https://www.instagram.com/reel/a/',
      title: 'A long title of a reel that never quite ends, as titles do',
      serverPath: 'a.mp4',
      folder: r'C:\Users\me\Videos\MeTube\Offline',
      phase: CopyPhase.pulling,
      progress: .4,
    ),
    LocalCopy(
      id: 'b',
      kind: CopyKind.download,
      canonicalUrl: 'https://www.instagram.com/reel/b/',
      title: 'Saved',
      serverPath: 'Kids/b.mp4',
      folder: r'C:\Users\me\Downloads\MeTube\Kids\and\deeper\folders',
      phase: CopyPhase.done,
      path: r'C:\Users\me\Downloads\MeTube\Kids\b.mp4',
    ),
  ];
}

ShellHarness _harness() => ShellHarness(
  library: const [],
  server: ServerConfig(baseUrl: 'http://nas:8081'),
  overrides: [
    desktopFoldersProvider.overrideWithValue(const _Folders()),
    localCopiesProvider.overrideWith(_Copies.new),
    initialAddressesProvider.overrideWithValue(
      const ServerAddresses(
        urls: [
          'http://192.168.1.10:8081',
          'https://metube.a-rather-long-domain-name.example.com',
        ],
        active: 'http://192.168.1.10:8081',
      ),
    ),
    endpointResolverProvider.overrideWithValue(
      EndpointResolver(probe: (url) async => MTEndpointStatus.unauthorized),
    ),
  ],
);

void main() {
  for (final pane in [
    'server',
    'network',
    'downloads',
    'folders',
    'desktop',
    'backup',
  ]) {
    testWidgets('settings: $pane', (tester) async {
      await expectNoOverflow(
        tester,
        _harness().app,
        then: (tester) async {
          GoRouter.of(tester.element(find.byType(EmberSidebar)))
              .go('/settings/$pane');
        },
      );
    });
  }

  testWidgets('the downloads panel, full', (tester) async {
    await expectNoOverflow(
      tester,
      () {
        final h = _harness();
        final waiting = h.engine.submit(
          'https://www.youtube.com/watch?v=aaaaaaaaaaa',
          Quality.best,
        );
        h.engine.fail(
          h.engine.submit('https://x.com/a/status/1', Quality.best),
          const NetworkException('dropped'),
        );
        expect(waiting.phase, TaskPhase.queued);
        return h.app();
      },
      then: (tester) async {
        await tester.tap(find.byType(DownloadsButton));
      },
    );
  });
}
