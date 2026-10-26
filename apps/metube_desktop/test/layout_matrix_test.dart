import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'
    show
        Builder,
        FilledButton,
        Positioned,
        PopupMenuItem,
        Scrollable,
        Stack,
        TextField;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/add/add_entry.dart';
import 'package:metube_desktop/features/add/batch_dialog.dart';
import 'package:metube_desktop/features/library/item_menu.dart';
import 'package:metube_desktop/features/library/library_item_view.dart';
import 'package:metube_desktop/features/library/library_page.dart';
import 'package:metube_desktop/features/library/library_state.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/drop_frame.dart';
import 'package:metube_desktop/shell/ember_shell.dart';
import 'package:metube_desktop/shell/key_cap.dart';
import 'package:metube_desktop/shell/pill.dart';
import 'package:metube_desktop/shell/right_panel.dart';
import 'package:metube_desktop/shell/shell_layout.dart';
import 'package:metube_desktop/shell/ui_zoom.dart';
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

/// Lists and channels with long names in both scripts, a pinned list, a
/// line whose clip is gone, a channel that failed and one paused.
ShellHarness _stocked({double zoom = 1.0}) {
  final h = ShellHarness(
    library: _library,
    server: _server,
    zoom: UiZoom(zoom),
    overrides: [
      playlistReaderProvider.overrideWithValue(
        (url) async => PlaylistPreview(
          kind: PlaylistKind.youtube,
          title: _longTitle,
          tracks: [
            for (final (i, title) in [_longTitle, _arabicTitle].indexed)
              PlaylistTrack(
                url: 'https://www.youtube.com/watch?v=${'$i'.padLeft(11, 'x')}',
                title: title,
                duration: const Duration(hours: 1, minutes: 2, seconds: 3),
              ),
          ],
        ),
      ),
    ],
  );
  h.api.folders = const ServerFolders(
    video: ['Homelab/Archive of long episodes', 'قناة المختبر الطويلة'],
  );
  unawaited(
    h.store.setString(
      PlaylistsStore.prefsKey,
      jsonEncode([
        for (final (i, name) in [
          'Evening listening for the long drive home, part two',
          'قائمة المساء الطويلة للطريق إلى البيت، الجزء الثاني',
          'Short',
        ].indexed)
          {
            'id': 'p$i',
            'name': name,
            'pinned': i < 2,
            'createdAt': DateTime(2026, 10, 1 + i).toIso8601String(),
            'items': [
              for (final item in _library) {'canonicalUrl': item.canonicalUrl},
              {
                'canonicalUrl': 'https://youtu.be/gone',
                'cachedTitle': _longTitle,
              },
            ],
          },
      ]),
    ),
  );
  unawaited(
    h.store.setString(
      'tags_index',
      jsonEncode({
        _url: ['homelab', 'backups', 'a tag with quite a long name indeed'],
      }),
    ),
  );
  h.api.subscriptions = [
    for (final (i, name) in [
      'Homelab Hour with a rather long channel name - Videos',
      'قناة المختبر - Videos',
      'GAMER SNACK | جيمر سناك - Videos',
    ].indexed)
      ChannelSubscription(
        id: 's$i',
        name: name,
        url: 'https://www.youtube.com/@channel$i/videos',
        enabled: i != 2,
        checkIntervalMinutes: 180,
        quality: 'best',
        titleRegex: i == 0 ? 'Episode|Live' : null,
        seenCount: 55,
        lastChecked: DateTime(2026, 10, 23),
        error: i == 1
            ? 'ERROR: [youtube:tab] channel0: This channel does not exist. '
                  'HTTP Error 404: Not Found'
            : null,
        folder: i == 0 ? 'Homelab/Archive of long episodes' : null,
      ),
  ];
  return h;
}

/// The stocked lists and channels, one place at a time.
const _stockedPlaces = [
  EmberRoutes.playlists,
  '/playlists/p0',
  '/playlists/p1',
  EmberRoutes.channels,
  '/channels/s0',
  '/channels/s1',
];

/// The clipboard as empty: the add button reads it, and a test has none.
void _emptyClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
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

  for (final place in _stockedPlaces) {
    testWidgets('stocked: $place', (tester) async {
      await expectNoOverflow(
        tester,
        () => _stocked().app(),
        then: (tester) async {
          GoRouter.of(tester.element(find.byType(LibraryPage))).go(place);
        },
      );
    });
  }

  testWidgets("a card's right-click menu", (tester) async {
    _emptyClipboard(tester);
    await expectNoOverflow(
      tester,
      () => _stocked().app(),
      then: (tester) async {
        // At twice the text the chips fill a short window; the grid is
        // further down.
        final page = find
            .descendant(
              of: find.byType(LibraryPage),
              matching: find.byType(Scrollable),
            )
            .first;
        for (var i = 0; i < 20; i++) {
          if (find.byType(LibraryItemView).evaluate().isNotEmpty) break;
          await tester.drag(page, const Offset(0, -100));
          await tester.pumpAndSettle();
        }
        // Its top edge: a card the drag just brought in may be cut below.
        await tester.tapAt(
          tester.getRect(find.byType(LibraryItemView).first).topCenter +
              const Offset(0, MTSpace.sm),
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuItem<ItemChoice>), findsWidgets);
      },
    );
  });

  testWidgets('the frame shown while links are dragged over the window', (
    tester,
  ) async {
    _emptyClipboard(tester);
    await expectNoOverflow(
      tester,
      () => ShellHarness(
        library: _library,
        server: _server,
        overrides: [
          linkDropProvider.overrideWithValue(
            (child, _) => Stack(
              children: [
                child,
                Positioned.fill(
                  child: Builder(
                    builder: (context) =>
                        DropFrame(label: context.mtl.desktopDropLinks),
                  ),
                ),
              ],
            ),
          ),
        ],
      ).app(),
      then: (tester) async => expect(find.byType(DropFrame), findsOneWidget),
    );
  });

  testWidgets('the shortcuts sheet, opened with "?"', (tester) async {
    _emptyClipboard(tester);
    await expectNoOverflow(
      tester,
      () => _stocked().app(),
      then: (tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.slash);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(find.byType(KeyCap), findsWidgets);
      },
    );
  });

  // The add dialogs, opened as a user would, over the library.
  for (final (name, text) in [
    ('one link', _url),
    (
      'several links',
      '$_url\nhttps://www.instagram.com/reel/Cxyz/\nhttps://example.org/a',
    ),
    ('a playlist', 'https://www.youtube.com/playlist?list=PLabcdefghijklmn'),
  ]) {
    testWidgets('adding: $name', (tester) async {
      _emptyClipboard(tester);
      await expectNoOverflow(
        tester,
        () => _stocked().app(),
        then: (tester) async {
          await tester.tap(
            find.byWidgetPredicate(
              (w) =>
                  w is MTShortcutTooltip &&
                  (w.message == 'Add link' || w.message == 'إضافة رابط'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, text);
          await tester.pumpAndSettle();
          if (name == 'a playlist') {
            await tester.tap(find.byType(FilledButton).last);
          }
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

  Future<void> readingRoom(WidgetTester tester, ShellHarness h) async {
    h.player.showPlaying(_queue, playing: false);
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(LibraryPage)))
        .go(EmberRoutes.reading(_url));
    await tester.pumpAndSettle();
    // With its find bar open, the tallest it gets.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }

  /// The listening room on the sound in the queue, opened from the bar.
  Future<void> listeningRoom(WidgetTester tester, ShellHarness h) async {
    h.player.showPlaying([_queue[1], _queue[0]], playing: false);
    await tester.pumpAndSettle();
    final english = find.byTooltip('Listening room');
    await tester.tap(
      english.evaluate().isEmpty ? find.byTooltip('غرفة الاستماع') : english,
    );
  }

  /// The clip page with its chapters listed beneath.
  Future<void> chapters(WidgetTester tester) async {
    GoRouter.of(tester.element(find.byType(LibraryPage)))
        .go(EmberRoutes.item(_url));
  }

  /// Both rooms read the same words; only which clip they belong to differs.
  ShellHarness withWords({double zoom = 1}) => ShellHarness(
    library: _library,
    server: _server,
    transcripts: {_url: _transcript, _queue[1].canonicalUrl: _transcript},
    zoom: UiZoom(zoom),
  );

  /// The library statistics, from the library's counts.
  Future<void> stats(WidgetTester tester) async {
    GoRouter.of(tester.element(find.byType(LibraryPage))).go(EmberRoutes.stats);
  }

  testWidgets('the library statistics', (tester) async {
    await expectNoOverflow(tester, () => withWords().app(), then: stats);
  });

  testWidgets('the listening room', (tester) async {
    late ShellHarness h;
    await expectNoOverflow(
      tester,
      () => (h = withWords()).app(),
      then: (tester) => listeningRoom(tester, h),
    );
  });

  testWidgets('a clip with its chapters', (tester) async {
    await expectNoOverflow(tester, () => withWords().app(), then: chapters);
  });

  testWidgets('the reading room, playing, finding', (tester) async {
    late ShellHarness h;
    await expectNoOverflow(
      tester,
      () => (h = ShellHarness(
        library: _library,
        server: _server,
        transcripts: {_url: _transcript},
      )).app(),
      then: (tester) => readingRoom(tester, h),
    );
  });

  // The interface size at both ends, each in its smallest window, and the
  // laptop that only fits at 90%.
  for (final (zoom, window) in [
    (0.8, const EmberWindowSize('smallest at 80%', Size(768, 480))),
    (1.5, const EmberWindowSize('smallest at 150%', Size(1440, 900))),
    (0.9, const EmberWindowSize('laptop 1093x566 at 90%', Size(1093, 566))),
  ]) {
    for (final mode in emberLibraryModes) {
      testWidgets('the library as ${mode.name}, ${window.name}', (
        tester,
      ) async {
        await expectNoOverflow(tester, () {
          final h = ShellHarness(
            library: _library,
            server: _server,
            zoom: UiZoom(zoom),
          );
          unawaited(h.store.setString(EmberLibraryNotifier.modeKey, mode.name));
          return h.app();
        }, windows: [window]);
      });
    }

    for (final place in _stockedPlaces) {
      testWidgets('stocked: $place, ${window.name}', (tester) async {
        await expectNoOverflow(
          tester,
          () => _stocked(zoom: zoom).app(),
          windows: [window],
          then: (tester) async {
            GoRouter.of(tester.element(find.byType(LibraryPage))).go(place);
          },
        );
      });
    }

    testWidgets('the reading room, ${window.name}', (tester) async {
      late ShellHarness h;
      await expectNoOverflow(
        tester,
        () => (h = ShellHarness(
          library: _library,
          server: _server,
          transcripts: {_url: _transcript},
          zoom: UiZoom(zoom),
        )).app(),
        windows: [window],
        then: (tester) => readingRoom(tester, h),
      );
    });

    testWidgets('the library statistics, ${window.name}', (tester) async {
      await expectNoOverflow(
        tester,
        () => withWords(zoom: zoom).app(),
        windows: [window],
        then: stats,
      );
    });

    testWidgets('the listening room, ${window.name}', (tester) async {
      late ShellHarness h;
      await expectNoOverflow(
        tester,
        () => (h = withWords(zoom: zoom)).app(),
        windows: [window],
        then: (tester) => listeningRoom(tester, h),
      );
    });

    testWidgets('a clip with its chapters, ${window.name}', (tester) async {
      await expectNoOverflow(
        tester,
        () => withWords(zoom: zoom).app(),
        windows: [window],
        then: chapters,
      );
    });

    for (final (i, tab) in PanelTab.values.indexed) {
      testWidgets('playing, ${tab.name} open, ${window.name}', (tester) async {
        late ShellHarness h;
        await expectNoOverflow(
          tester,
          () => (h = ShellHarness(
            library: _library,
            server: _server,
            transcripts: {_url: _transcript},
            zoom: UiZoom(zoom),
          )).app(),
          windows: [window],
          then: (tester) async {
            h.player.showPlaying(_queue, playing: false);
            await tester.pumpAndSettle();
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
}
