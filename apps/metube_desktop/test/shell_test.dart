import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/player_bar.dart';
import 'package:metube_desktop/shell/right_panel.dart';
import 'package:metube_desktop/shell/shell_layout.dart';
import 'package:metube_desktop/shell/shell_metrics.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:metube_desktop/shell/title_bar.dart';

import 'package:mt_core/mt_core.dart';

import 'support/shell_harness.dart';

void main() {
  Future<ShellHarness> open(
    WidgetTester tester,
    Size size, {
    ShellLayout layout = const ShellLayout(),
    bool arabic = false,
  }) async {
    ShellHarness.useWindow(tester, size);
    if (arabic) ShellHarness.useArabic(tester);
    final h = ShellHarness(layout: layout);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  double width(WidgetTester tester, Finder f) => tester.getSize(f).width;

  testWidgets('at 1440 the three columns stand side by side', (tester) async {
    await open(tester, const Size(1440, 900));
    expect(
      width(tester, find.byType(EmberSidebar)),
      EmberShellSize.sidebarWide,
    );
    expect(width(tester, find.byType(EmberRightPanel)), EmberShellSize.panel);
    expect(
      tester.getSize(find.byType(EmberPlayerBar)).height,
      EmberShellSize.playerBar,
    );
    expect(
      tester.getSize(find.byType(EmberTitleBar)).height,
      EmberShellSize.titleBar,
    );
  });

  testWidgets('at 1200 the sidebar narrows and the panel stays', (
    tester,
  ) async {
    await open(tester, const Size(1200, 800));
    expect(
      width(tester, find.byType(EmberSidebar)),
      EmberShellSize.sidebarNarrow,
    );
    expect(find.byType(EmberRightPanel), findsOneWidget);
  });

  testWidgets('at 1000 the panel is a layer, opened and closed by its button', (
    tester,
  ) async {
    final h = await open(tester, const Size(1000, 700));
    expect(find.byType(EmberRightPanel), findsNothing);

    await tester.tap(byLabel('Show side panel'));
    await tester.pumpAndSettle();
    expect(find.byType(EmberRightPanel), findsOneWidget);
    // A layer, so the user's saved choice is untouched.
    expect(await h.store.getString(ShellLayoutStore.key), isNull);

    await tester.tap(byLabel('Hide side panel'));
    await tester.pumpAndSettle();
    expect(find.byType(EmberRightPanel), findsNothing);
  });

  testWidgets('folding a column is saved for the next start', (tester) async {
    final h = await open(tester, const Size(1440, 900));
    await tester.tap(byLabel('Hide side panel'));
    await tester.tap(find.text('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(find.byType(EmberRightPanel), findsNothing);
    expect(
      width(tester, find.byType(EmberSidebar)),
      EmberShellSize.sidebarNarrow,
    );
    final saved = await ShellLayoutStore(
      store: h.store,
      mutex: PrefsMutex(),
    ).read();
    expect(saved, const ShellLayout(sidebarNarrow: true, panelHidden: true));
  });

  testWidgets('the sidebar opens each place and shows which is current', (
    tester,
  ) async {
    await open(tester, const Size(1440, 900));
    EmberPlace current() =>
        tester.widget<EmberSidebar>(find.byType(EmberSidebar)).current;
    for (final (label, place) in [
      ('Favorites', EmberPlace.favorites),
      ('Offline', EmberPlace.offline),
      ('Search', EmberPlace.search),
      ('Playlists', EmberPlace.playlists),
      ('Channels', EmberPlace.channels),
      ('Settings', EmberPlace.settings),
      ('Library', EmberPlace.library),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(current(), place, reason: label);
    }
  });

  testWidgets('back and forward walk the places visited', (tester) async {
    await open(tester, const Size(1440, 900));
    EmberPlace current() =>
        tester.widget<EmberSidebar>(find.byType(EmberSidebar)).current;
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(byLabel('Back'));
    await tester.pumpAndSettle();
    expect(current(), EmberPlace.search);
    await tester.tap(byLabel('Back'));
    await tester.pumpAndSettle();
    expect(current(), EmberPlace.library);
    await tester.tap(byLabel('Forward'));
    await tester.pumpAndSettle();
    expect(current(), EmberPlace.search);
  });

  testWidgets('**the gate**: moving around never touches the playback', (
    tester,
  ) async {
    final h = await open(tester, const Size(1440, 900));
    h.player.showPlaying([clip('Night Drive'), clip('Blue Hour')]);
    await tester.pumpAndSettle();
    final bar = tester.element(find.byType(EmberPlayerBar));
    for (final label in ['Search', 'Playlists', 'Settings', 'Library']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(byLabel('Back'));
    await tester.pumpAndSettle();
    expect(h.player.calls, isEmpty);
    // The same bar, never rebuilt from scratch, still showing the clip.
    expect(tester.element(find.byType(EmberPlayerBar)), same(bar));
    expect(
      find.descendant(
        of: find.byType(EmberPlayerBar),
        matching: find.text('Night Drive'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the player bar drives the player', (tester) async {
    final h = await open(tester, const Size(1440, 900));
    h.player.showPlaying([clip('Night Drive')]);
    await tester.pumpAndSettle();
    await tester.tap(byLabel('Pause'));
    await tester.tap(byLabel('Next'));
    await tester.tap(byLabel('Previous'));
    await tester.tap(byLabel('Shuffle'));
    await tester.tap(byLabel('Playback speed'));
    expect(h.player.calls, [
      'pause',
      'next',
      'previous',
      'shuffle true',
      'speed 1.25',
    ]);
  });

  testWidgets('with nothing queued the controls stay, dimmed and inert', (
    tester,
  ) async {
    final h = await open(tester, const Size(1440, 900));
    await tester.tap(byLabel('Play'), warnIfMissed: false);
    await tester.tap(byLabel('Next'), warnIfMissed: false);
    expect(h.player.calls, isEmpty);
    expect(find.text('Nothing playing'), findsWidgets);
  });

  testWidgets(
    'the queue button on the player bar opens "Up next" in the panel',
    (tester) async {
      await open(
        tester,
        const Size(1440, 900),
        layout: const ShellLayout(panelHidden: true),
      );
      expect(find.byType(EmberRightPanel), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(EmberPlayerBar),
          matching: byLabel('Queue'),
        ),
      );
      await tester.pumpAndSettle();
      final panel = tester.widget<EmberRightPanel>(
        find.byType(EmberRightPanel),
      );
      expect(panel.tab, PanelTab.upNext);
    },
  );

  testWidgets('the title bar works the window', (tester) async {
    final h = await open(tester, const Size(1440, 900));
    await tester.tap(byLabel('Minimize'));
    await tester.tap(byLabel('Maximize'));
    await tester.tap(byLabel('Close'));
    expect(h.controls.calls, ['minimize', 'toggleMaximize', 'close']);

    h.controls.maximized.value = true;
    await tester.pump();
    expect(byLabel('Restore down'), findsOneWidget);
  });

  testWidgets('a double click on the title bar maximizes', (tester) async {
    final h = await open(tester, const Size(1440, 900));
    final title = find.text('MeTube Ember');
    await tester.tap(title);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(h.controls.calls, contains('toggleMaximize'));
  });

  testWidgets('in Arabic the sidebar moves right and the transport does not', (
    tester,
  ) async {
    await open(tester, const Size(1440, 900), arabic: true);
    final side = tester.getRect(find.byType(EmberSidebar));
    final panel = tester.getRect(find.byType(EmberRightPanel));
    expect(side.left, greaterThan(panel.left));
    expect(side.right, 1440);

    // Previous stays left of next, as time runs left to right.
    final previous = tester.getCenter(byLabel('السابق'));
    final next = tester.getCenter(byLabel('التالي'));
    expect(previous.dx, lessThan(next.dx));
  });

  for (final arabic in [false, true]) {
    for (final size in [const Size(960, 600), const Size(1920, 1080)]) {
      testWidgets('no overflow at $size, ${arabic ? 'Arabic' : 'English'}', (
        tester,
      ) async {
        for (final scale in [1.0, 1.3, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await open(tester, size, arabic: arabic);
          expect(tester.takeException(), isNull, reason: 'text x$scale');
        }
      });
    }
  }
}
