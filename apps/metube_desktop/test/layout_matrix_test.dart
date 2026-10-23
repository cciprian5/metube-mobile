import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/library/library_page.dart';
import 'package:metube_desktop/features/library/library_state.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/ember_shell.dart';
import 'package:metube_desktop/shell/pill.dart';
import 'package:metube_desktop/shell/right_panel.dart';
import 'package:metube_desktop/shell/shell_layout.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'desktop_matrix.dart';
import 'support/shell_harness.dart';

// Every screen and panel Ember has, through the window matrix. The titles
// are long on purpose, in both scripts: a short title fits anywhere.

const _url = 'https://youtu.be/aaaaaaaaaaa';
const _longTitle =
    'Homelab Hour - Ep. 12: snapshots, replication and why a second box '
    'in another room is the only backup that counts';
const _arabicTitle =
    'ساعة المختبر المنزلي - الحلقة 12: اللقطات والنسخ المتماثل ولماذا لا '
    'تُعدّ نسخة احتياطية إلا تلك التي في جهاز آخر';

final _server = ServerConfig(baseUrl: 'http://nas:8081');

final _library = [
  LibraryItem(
    canonicalUrl: _url,
    title: _longTitle,
    uploader: 'Homelab Hour with a rather long channel name',
    onServer: true,
    timestamp: DateTime(2026, 10, 20),
    sizeBytes: 400000000,
    duration: const Duration(hours: 1, minutes: 12, seconds: 5),
    tags: const ['homelab', 'backups', 'zfs'],
    favorite: true,
  ),
  LibraryItem(
    canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
    title: _arabicTitle,
    uploader: 'قناة المختبر',
    onServer: true,
    isAudio: true,
    timestamp: DateTime(2026, 10, 21),
    sizeBytes: 100,
  ),
  LibraryItem(
    canonicalUrl: 'https://youtu.be/ccccccccccc',
    title: 'Blue Hour',
    onServer: true,
    localPath: r'C:\Offline\blue.mp4',
    timestamp: DateTime(2026, 10, 22),
    sizeBytes: 900,
    duration: const Duration(seconds: 40),
    aspectRatio: 0.56,
  ),
  LibraryItem(
    canonicalUrl: 'https://www.tiktok.com/@a/video/1',
    title: 'Tidepools at Dawn',
    onServer: true,
    timestamp: DateTime(2026, 10, 19),
    sizeBytes: 50,
  ),
];

final _queue = [
  PlaylistItem(
    canonicalUrl: _url,
    title: _longTitle,
    uploader: 'Homelab Hour with a rather long channel name',
    serverFilename: 'Homelab Hour [aaaaaaaaaaa].mp4',
    duration: const Duration(hours: 1, minutes: 12, seconds: 5),
  ),
  PlaylistItem(
    canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
    title: _arabicTitle,
    uploader: 'قناة المختبر',
    isAudio: true,
  ),
  clip('Blue Hour'),
];

final _transcript = Transcript(
  canonicalUrl: _url,
  language: 'en',
  source: 'sidecar',
  fetchedAt: DateTime(2026, 10, 24),
  segments: [
    for (var s = 0; s < 40; s++)
      TranscriptSegment(
        start: Duration(seconds: s * 20),
        end: Duration(seconds: s * 20 + 19),
        text: s.isEven
            ? 'A snapshot on the same pool is not a backup: if the pool '
                  'dies, every snapshot goes with it.'
            : 'اللقطة على المجمع نفسه ليست نسخة احتياطية، فإن تلف المجمع '
                  'ذهبت معه كل اللقطات.',
      ),
  ],
);

/// The provider container behind the screen on display.
ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(EmberShell)));

/// Opens the side panel when the window is too narrow to show it beside.
Future<void> _openPanel(WidgetTester tester) async {
  if (find.byType(EmberRightPanel).evaluate().isNotEmpty) return;
  await tester.tap(
    find.byWidgetPredicate(
      (w) =>
          w is MTShortcutTooltip &&
          (w.message == 'Show side panel' ||
              w.message == 'إظهار اللوحة الجانبية'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nothing set up yet', (tester) async {
    await expectNoOverflow(tester, () => ShellHarness().app());
  });

  testWidgets('a server with an empty library', (tester) async {
    await expectNoOverflow(
      tester,
      () => ShellHarness(library: const [], server: _server).app(),
    );
  });

  for (final mode in emberLibraryModes) {
    testWidgets('the library as ${mode.name}', (tester) async {
      await expectNoOverflow(tester, () {
        final h = ShellHarness(library: _library, server: _server);
        unawaited(h.store.setString(EmberLibraryNotifier.modeKey, mode.name));
        return h.app();
      });
    });
  }

  testWidgets('the server stopped answering', (tester) async {
    await expectNoOverflow(
      tester,
      () => ShellHarness(
        library: _library,
        server: _server,
        serverError: Exception('down'),
      ).app(),
    );
  });

  testWidgets('filters that hide everything', (tester) async {
    await expectNoOverflow(
      tester,
      () => ShellHarness(library: _library, server: _server).app(),
      then: (tester) async {
        _container(tester).read(libraryViewProvider.notifier)
          ..setType(MediaTypeFilter.audio)
          ..togglePlatform(MediaPlatform.tiktok);
      },
    );
  });

  testWidgets('the sidebar narrow and the panel folded', (tester) async {
    await expectNoOverflow(
      tester,
      () => ShellHarness(
        layout: const ShellLayout(sidebarNarrow: true, panelHidden: true),
        library: _library,
        server: _server,
      ).app(),
    );
  });

  for (final place in [
    EmberRoutes.favorites,
    EmberRoutes.offline,
    EmberRoutes.search,
    EmberRoutes.playlists,
    EmberRoutes.channels,
    EmberRoutes.settings,
  ]) {
    testWidgets('the place $place', (tester) async {
      await expectNoOverflow(
        tester,
        () => ShellHarness(library: _library, server: _server).app(),
        then: (tester) async {
          GoRouter.of(tester.element(find.byType(LibraryPage))).go(place);
        },
      );
    });
  }

  for (final (i, tab) in PanelTab.values.indexed) {
    testWidgets('playing, with the ${tab.name} tab open', (tester) async {
      late ShellHarness h;
      await expectNoOverflow(
        tester,
        () => (h = ShellHarness(
          library: _library,
          server: _server,
          transcripts: {_url: _transcript},
        )).app(),
        then: (tester) async {
          h.player.showPlaying(_queue, playing: false);
          await tester.pumpAndSettle();
          h.player.reach(const Duration(minutes: 7));
          await _openPanel(tester);
          await tester.tap(
            find
                .descendant(
                  of: find.byType(EmberRightPanel),
                  matching: find.byType(EmberPill),
                )
                .at(i),
          );
        },
      );
    });
  }
}
