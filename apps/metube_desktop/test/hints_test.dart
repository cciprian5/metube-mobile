import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/desktop_habits.dart';
import 'package:metube_desktop/data/hints_data.dart';
import 'package:metube_desktop/data/notices.dart';
import 'package:metube_desktop/data/setup_data.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/hints_wiring.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

class _Notices implements NoticePort {
  final shown = <EmberNotice>[];

  @override
  Future<void> show(EmberNotice notice) async => shown.add(notice);
}

final _clip = LibraryItem(
  canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
  title: 'Amber Skies',
  onServer: true,
  serverFilename: 'amber.mp4',
  timestamp: DateTime(2026, 10, 20),
);

const _tip = 'Tip: press ? for the keyboard shortcuts.';

void main() {
  Future<(ShellHarness, ProviderContainer, _Notices)> open(
    WidgetTester tester,
  ) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final notices = _Notices();
    final h = ShellHarness(
      library: [_clip],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      overrides: [noticePortProvider.overrideWithValue(notices)],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmberSidebar)),
    );
    return (h, container, notices);
  }

  Future<void> playFor(WidgetTester tester, ShellHarness h) async {
    h.player.showPlaying([toPlaylistItem(_clip)]);
    await tester.pump();
    await tester.pump(HintsWiring.settle + const Duration(seconds: 1));
    // The notice slides in.
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder tip() => find.textContaining(_tip);

  testWidgets('**the guard**: the shortcuts tip comes a few seconds into '
      'the first clip, once in a lifetime', (tester) async {
    final (h, c, _) = await open(tester);
    await playFor(tester, h);
    expect(tip(), findsOneWidget);
    expect(c.read(hintsProvider).seen, contains(EmberHint.shortcuts));
    expect(await h.store.getString(Hints.seenKey), 'shortcuts');
    await tester.pump(const Duration(seconds: 10));
    // Another session: the tips read again from what was kept.
    c.invalidate(hintsProvider);
    c.read(hintsProvider);
    await tester.pump();
    h.player.showPlaying([toPlaylistItem(_clip)], playing: false);
    await tester.pump();
    await playFor(tester, h);
    expect(tip(), findsNothing);
  });

  testWidgets('**the guard**: no tip for someone already using the keys', (
    tester,
  ) async {
    final (h, c, _) = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    await playFor(tester, h);
    expect(tip(), findsNothing);
    expect(c.read(hintsProvider).seen, contains(EmberHint.shortcuts));
  });

  testWidgets('**the guard**: none in a session that already interrupted', (
    tester,
  ) async {
    final (h, c, _) = await open(tester);
    c.read(hintsProvider.notifier).interrupted();
    await playFor(tester, h);
    expect(tip(), findsNothing);
    // Not spent: another session may still show it.
    expect(c.read(hintsProvider).seen, isNot(contains(EmberHint.shortcuts)));
  });

  testWidgets('**the guard**: none with tips off, and the choice is kept', (
    tester,
  ) async {
    final (h2, c2, _) = await open(tester);
    await c2.read(hintsProvider.notifier).setOn(false);
    await playFor(tester, h2);
    expect(tip(), findsNothing);
    expect(await h2.store.getBool(Hints.onKey), isFalse);
  });

  testWidgets('**the guard**: the first close to the tray says the app '
      'still runs, as a Windows notice, once', (tester) async {
    final (h, c, notices) = await open(tester);
    h.controls.close();
    await tester.pump();
    // The tray is off: the close quits, nothing to say.
    expect(notices.shown, isEmpty);
    await c.read(closeToTrayProvider.notifier).set(true);
    h.controls.close();
    await tester.pump();
    h.controls.close();
    await tester.pump();
    expect(notices.shown.map((n) => n.title), [
      'MeTube Ember is still running',
    ]);
  });

  testWidgets('**the guard**: Discover lists the features from About, and '
      '"Try it" goes there', (tester) async {
    final (_, _, _) = await open(tester);
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberSettingsPane.about.route);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Discover MeTube Ember')),
      findsOneWidget,
    );
    expect(find.text('Reading room'), findsOneWidget);
    final stats = find.ancestor(
      of: find.text('Library statistics'),
      matching: find.byType(Row),
    );
    await tester.ensureVisible(stats.first);
    await tester.tap(
      find.descendant(of: stats.first, matching: find.text('Try it')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final router = GoRouter.of(tester.element(find.byType(EmberSidebar)));
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      EmberRoutes.stats,
    );
  });

  testWidgets('**the guard**: the server setup at the first start is the '
      "session's one interruption", (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      overrides: [offerSetupAtStartProvider.overrideWithValue(true)],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(
      tester.element(find.byType(EmberSidebar)),
    );
    expect(c.read(hintsProvider.notifier).wants(EmberHint.shortcuts), isFalse);
    expect(c.read(hintsProvider.notifier).wants(EmberHint.tray), isTrue);
  });
}
