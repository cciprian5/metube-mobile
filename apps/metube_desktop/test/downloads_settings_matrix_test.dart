import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/addresses_data.dart';
import 'package:metube_desktop/data/backup_data.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/data/local_copies.dart';
import 'package:metube_desktop/data/sync_data.dart';
import 'package:metube_desktop/data/transcripts_data.dart';
import 'package:metube_desktop/data/update_data.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/features/downloads/downloads_button.dart';
import 'package:metube_desktop/features/settings/whats_new.dart';
import 'package:metube_desktop/features/setup/setup_dialog.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

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

/// Long on purpose, in both scripts.
const _longTitle =
    'A very long title about replicating snapshots to a second box every '
    'single night, and why a snapshot on the same pool is not a backup';

final _library = [
  LibraryItem(
    canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
    title: _longTitle,
    uploader: 'A channel with a rather long name of its own',
    onServer: true,
    timestamp: DateTime(2026, 10, 20),
  ),
  LibraryItem(
    canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
    title: 'نسخ اللقطات إلى صندوق ثانٍ كل ليلة، ولماذا لا تكفي اللقطة وحدها',
    onServer: true,
    timestamp: DateTime(2026, 10, 21),
  ),
];

TranscriptIndex _index() => TranscriptIndex()
  ..add(
    Transcript(
      canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
      language: 'en',
      source: 'sidecar',
      fetchedAt: DateTime(2026, 10, 24),
      segments: [
        TranscriptSegment(
          start: const Duration(hours: 1, minutes: 2, seconds: 3),
          end: const Duration(hours: 1, minutes: 2, seconds: 9),
          text:
              'So we replicate the snapshots to a second box every night, '
              'because a snapshot on the same pool goes down with the pool.',
        ),
      ],
    ),
  );

ShellHarness _harness({List<LibraryItem> library = const []}) => ShellHarness(
  library: library,
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
    // A log that is never written: the pane shows its empty state.
    loggerProvider.overrideWithValue(MTLogger(filePath: 'no-such-log.txt')),
    installedVersionProvider.overrideWith((ref) async => '0.12.10'),
    transcriptIndexProvider.overrideWith((ref) async => _index()),
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
    'cookies',
    'logs',
    'about',
    'subscriptions',
    'appearance',
    'transcripts',
    'updates',
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

  testWidgets('settings: updates, with a version found and long notes', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      () => ShellHarness(
        library: const [],
        server: ServerConfig(baseUrl: 'http://nas:8081'),
        overrides: [
          installedVersionProvider.overrideWith((ref) async => '0.12.10'),
          updateProvider.overrideWith(_Found.new),
        ],
      ).app(),
      then: (tester) async {
        GoRouter.of(tester.element(find.byType(EmberSidebar)))
            .go('/settings/updates');
      },
    );
  });

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

  testWidgets('the first-run setup, with servers found', (tester) async {
    await expectNoOverflow(
      tester,
      () => ShellHarness(
        library: const [],
        overrides: [
          setupHintProvider.overrideWith(
            (ref) => ['https://metube.a-rather-long-domain-name.example.com'],
          ),
        ],
      ).app(),
      then: (tester) async {
        unawaited(showSetupDialog(tester.element(find.byType(EmberSidebar))));
      },
    );
  });

  testWidgets('the palette, with every kind of result', (tester) async {
    await expectNoOverflow(
      tester,
      () => _harness(library: _library).app(),
      then: (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        // The commands were drawn on opening; now a title, a moment with
        // an hour in its time, and saving.
        await tester.enterText(find.byType(TextField).last, 'snapshot');
      },
    );
  });

  testWidgets("what's new, in the middle of the window", (tester) async {
    await expectNoOverflow(
      tester,
      () => _harness().app(),
      then: (tester) async {
        unawaited(
          showWhatsNewDialog(
            tester.element(find.byType(EmberSidebar)),
            const WhatsNew(
              version: '0.12.10',
              notes: '## Fixed\n- $_longTitle\n- $_longTitle',
              pageUrl: 'https://example.com/releases/tag/v0.12.10',
            ),
          ),
        );
      },
    );
  });

  testWidgets('settings: sync, on, with a phone and a long folder', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync(
      'ember matrix a folder with a rather long name, as OneDrive makes them',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    await expectNoOverflow(
      tester,
      () {
        final h = ShellHarness(
          library: const [],
          overrides: [
            loggerProvider.overrideWithValue(
              MTLogger(filePath: '${root.path}/log.txt'),
            ),
            syncReportProvider.overrideWith(
              (ref) => SyncReport(
                at: DateTime.now(),
                cameBack: true,
                devices: [
                  SyncDevice(
                    SyncSnapshot(
                      deviceId: 'phone-a1b2',
                      deviceKind: 'phone',
                      writtenAt: DateTime.now().millisecondsSinceEpoch,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        unawaited(h.store.setString(SyncSettingsNotifier.folderKey, root.path));
        unawaited(
          h.store.setString(SyncSettingsNotifier.deviceKey, 'ember-c3d4'),
        );
        return h.app();
      },
      then: (tester) async {
        GoRouter.of(tester.element(find.byType(EmberSidebar)))
            .go('/settings/sync');
      },
    );
  });
}

/// A version already found, with notes long enough to wrap.
class _Found extends UpdateNotifier {
  @override
  UpdateState build() => UpdateState(
    phase: UpdatePhase.available,
    release: UpdateRelease(
      version: AppVersion.tryParse('0.13.0')!,
      tag: 'v0.13.0',
      apkUrl: 'https://x/setup.exe',
      apkSize: 28000000,
      notes:
          '## Fixed\n- ${'The palette opens at once, and the reading room '
                  'keeps its place when the window is resized. ' * 3}\n'
          '## Added\n- Updates install themselves.',
    ),
  );
}
