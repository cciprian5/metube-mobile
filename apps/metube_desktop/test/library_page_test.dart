import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/library/library_state.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/pill.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

final _library = [
  LibraryItem(
    canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
    title: 'Homelab Hour - Ep. 12',
    uploader: 'Homelab Hour',
    onServer: true,
    timestamp: DateTime(2026, 10, 20),
    sizeBytes: 400,
    tags: const ['homelab'],
    favorite: true,
  ),
  LibraryItem(
    canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
    title: 'Amber Skies',
    uploader: 'Lowlands',
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

void main() {
  Future<ShellHarness> open(
    WidgetTester tester, {
    List<LibraryItem>? library,
    ServerConfig? server,
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(library: library, server: server);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  Finder titleOf(String t) => find.text(t);
  final server = ServerConfig(baseUrl: 'http://nas:8081');

  testWidgets('no server and nothing local: it says so plainly', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('No server configured'), findsOneWidget);
  });

  testWidgets('the library opens in the grid, newest first', (tester) async {
    await open(tester, library: _library, server: server);
    expect(find.byType(MTMediaGridCard), findsNWidgets(4));
    final titles = [
      for (final t in ['Blue Hour', 'Amber Skies', 'Homelab Hour - Ep. 12'])
        tester.getTopLeft(titleOf(t)).dx,
    ];
    // Left to right in English: the newest leads.
    expect(titles[0], lessThan(titles[1]));
    expect(titles[1], lessThan(titles[2]));
    expect(find.textContaining('4 clips'), findsOneWidget);
    expect(find.textContaining('1 offline'), findsOneWidget);
  });

  testWidgets('the kind chips filter, and a second click clears', (
    tester,
  ) async {
    await open(tester, library: _library, server: server);
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    expect(find.byType(MTMediaGridCard), findsOneWidget);
    expect(titleOf('Amber Skies'), findsOneWidget);

    await tester.tap(find.text('Shorts'));
    await tester.pumpAndSettle();
    expect(titleOf('Blue Hour'), findsOneWidget);
    expect(find.byType(MTMediaGridCard), findsOneWidget);

    await tester.tap(find.text('Shorts'));
    await tester.pumpAndSettle();
    expect(find.byType(MTMediaGridCard), findsNWidgets(4));
  });

  testWidgets('the platforms are one pill whose menu carries live counts, '
      'most first', (tester) async {
    await open(tester, library: _library, server: server);
    // **The guard**: no row of platform pills, no dot before a count.
    expect(find.text('YouTube · 3'), findsNothing);
    await tester.tap(find.text('Platform'));
    await tester.pumpAndSettle();
    final youtube = tester.getTopLeft(find.text('YouTube').last);
    final tiktok = tester.getTopLeft(find.text('TikTok').last);
    expect(youtube.dy, lessThan(tiktok.dy));
    expect(find.text(mtLtrRun('3')), findsOneWidget);
    await tester.tap(find.text('TikTok').last);
    await tester.pumpAndSettle();
    expect(find.byType(MTMediaGridCard), findsOneWidget);
    // The pill now names the platform chosen.
    expect(find.widgetWithText(EmberPill, 'TikTok'), findsOneWidget);
  });

  testWidgets('a tag picked in the menu includes, then excludes, then lets '
      'go', (tester) async {
    await open(tester, library: _library, server: server);
    Future<void> pick() async {
      await tester.tap(find.widgetWithText(EmberPill, 'Tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(mtName('#homelab')).last);
      await tester.pumpAndSettle();
      // The menu reopens for another pick; Escape closes it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }

    await pick();
    expect(find.byType(MTMediaGridCard), findsOneWidget);
    await pick();
    expect(find.byType(MTMediaGridCard), findsNWidgets(3));
    await pick();
    expect(find.byType(MTMediaGridCard), findsNWidgets(4));
  });

  testWidgets('**the guard**: the counts follow the place; an empty Offline '
      'page offers no platform at all', (tester) async {
    await open(tester, library: _library, server: server);
    expect(find.text('Platform'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberRoutes.offline);
    await tester.pumpAndSettle();
    expect(find.text('Platform'), findsNothing);
  });

  testWidgets('favourites is one state for its chip and its sidebar entry', (
    tester,
  ) async {
    await open(tester, library: _library, server: server);
    await tester.tap(find.widgetWithText(InkWell, 'Favorites').first);
    await tester.pumpAndSettle();
    expect(find.byType(MTMediaGridCard), findsOneWidget);
    expect(find.text('Homelab Hour - Ep. 12'), findsWidgets);
  });

  testWidgets('the table sorts from its header, and the choice is kept', (
    tester,
  ) async {
    final h = await open(tester, library: _library, server: server);
    await tester.tap(find.bySemanticsLabel('Table'));
    await tester.pumpAndSettle();
    expect(find.byType(MTMediaRow), findsNWidgets(4));
    // **The guard**: only the copy on this computer is marked, not
    // "Server" on every row, and no platform letters beside the titles.
    expect(find.byType(MTLocationBadge), findsOneWidget);
    expect(find.byType(MTPlatformChip), findsNothing);
    // **The guard**: the source column names the site, for every row, the
    // server's too; it used to stay empty.
    expect(
      find.descendant(
        of: find.byType(MTMediaRow),
        matching: find.text('YouTube'),
      ),
      findsWidgets,
    );
    expect(await h.store.getString(EmberLibraryNotifier.modeKey), 'list');

    await tester.tap(find.text('Size'));
    await tester.pumpAndSettle();
    double y(String t) => tester.getTopLeft(titleOf(t)).dy;
    expect(y('Blue Hour'), lessThan(y('Homelab Hour - Ep. 12')));
    expect(y('Homelab Hour - Ep. 12'), lessThan(y('Amber Skies')));
    expect(await h.store.getString(EmberLibraryNotifier.sortKey), 'largest');

    await tester.tap(find.text('Size'));
    await tester.pumpAndSettle();
    expect(y('Tidepools at Dawn'), lessThan(y('Amber Skies')));
  });

  testWidgets('a double click plays the list on screen from that clip', (
    tester,
  ) async {
    final h = await open(tester, library: _library, server: server);
    // Audio: it plays from the bar and the list stays on screen. (Any
    // shorts loop left on is let go first.)
    await doubleClick(tester, titleOf('Amber Skies'));
    await tester.pumpAndSettle();
    expect(h.player.calls, ['loop false', 'playItems']);
    expect(find.byType(MTMediaGridCard), findsNWidgets(4));
  });

  testWidgets('**the guard**: favourites and offline count their own, and '
      'an empty one says what fills it, not that a filter hides it', (
    tester,
  ) async {
    await open(
      tester,
      library: [
        for (final i in _library)
          if (i.localPath == null) i,
      ],
      server: server,
    );
    void go(String to) =>
        GoRouter.of(tester.element(find.byType(EmberSidebar))).go(to);
    go(EmberRoutes.favorites);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 clip'), findsOneWidget);

    go(EmberRoutes.offline);
    await tester.pumpAndSettle();
    expect(find.text('Nothing kept on this computer yet'), findsOneWidget);
    expect(find.text('Nothing matches these filters'), findsNothing);
    expect(find.textContaining('No clips yet'), findsOneWidget);
  });

  testWidgets('filters that hide everything offer to clear them', (
    tester,
  ) async {
    await open(tester, library: _library, server: server);
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Platform'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TikTok').last);
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches these filters'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.byType(MTMediaGridCard), findsNWidgets(4));
  });

  testWidgets("**the guard**: YouTube's cover goes without the password", (
    tester,
  ) async {
    final locked = ServerConfig(
      baseUrl: 'http://nas:8081',
      username: 'owner',
      password: 'secret',
    );
    await open(
      tester,
      server: locked,
      library: [
        LibraryItem(
          canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
          title: 'From YouTube',
          onServer: true,
          thumbnail: 'https://i.ytimg.com/vi/aaaaaaaaaaa/hqdefault.jpg',
        ),
        LibraryItem(
          canonicalUrl: 'https://example.com/b',
          title: 'Cover on the server',
          onServer: true,
          thumbnail: 'http://nas:8081/download/b.jpg',
        ),
        const LibraryItem(canonicalUrl: 'https://example.com/c', title: 'None'),
      ],
    );
    final covers = {
      for (final c in tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      ))
        c.imageUrl: c.httpHeaders ?? const {},
    };
    expect(covers.keys, hasLength(2));
    expect(covers['https://i.ytimg.com/vi/aaaaaaaaaaa/hqdefault.jpg'], isEmpty);
    expect(covers['http://nas:8081/download/b.jpg'], contains('Authorization'));
  });

  testWidgets('**the guard**: no Material icon on screen, in any layout', (
    tester,
  ) async {
    // The source check catches `Icons.` written in this app; this one
    // catches the shared widgets it draws.
    await open(tester, library: _library, server: server);
    for (final mode in ['Grid', 'Table', 'Compact']) {
      await tester.tap(find.bySemanticsLabel(mode));
      await tester.pumpAndSettle();
      expect(find.byType(Icon), findsNothing, reason: mode);
    }
  });

  for (final mode in ['Grid', 'Table', 'Compact']) {
    for (final size in [const Size(960, 600), const Size(1920, 1080)]) {
      testWidgets('$mode fits at $size in both languages, any text size', (
        tester,
      ) async {
        for (final arabic in [false, true]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            ShellHarness.useWindow(tester, size);
            tester.platformDispatcher.localesTestValue = [
              Locale(arabic ? 'ar' : 'en'),
            ];
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            final h = ShellHarness(library: _library, server: server);
            await tester.pumpWidget(h.app());
            await tester.pumpAndSettle();
            await tester.tap(
              find.bySemanticsLabel(switch ((mode, arabic)) {
                ('Grid', false) => 'Grid',
                ('Grid', true) => 'شبكة',
                ('Table', false) => 'Table',
                ('Table', true) => 'جدول',
                (_, false) => 'Compact',
                _ => 'مختصر',
              }),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$mode ar=$arabic x$scale',
            );
          }
        }
      });
    }
  }
}
