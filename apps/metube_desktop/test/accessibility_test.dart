import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/features/library/library_item_view.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/focus_regions.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

// What a screen reader is offered: every control that can be pressed has a
// name, in every place and every layer the window opens.

const _video = PlaylistItem(
  canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
  title: 'Night Drive',
  uploader: 'Field Notes',
);

void main() {
  Future<ShellHarness> open(WidgetTester tester) async {
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
    final root = Directory.systemTemp.createTempSync('ember_a11y_');
    addTearDown(() => root.deleteSync(recursive: true));
    final h = ShellHarness(
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      library: [
        LibraryItem(
          canonicalUrl: _video.canonicalUrl,
          title: _video.title,
          uploader: _video.uploader,
          onServer: true,
          serverFilename: 'Night Drive.mp4',
          timestamp: DateTime(2026, 10, 20),
        ),
      ],
      overrides: [
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${root.path}/ember.log'),
        ),
      ],
    );
    await tester.pumpWidget(h.app());
    // Something in the player, so its bar has all its controls; paused,
    // so the test settles.
    h.player.showPlaying([_video], playing: false);
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> go(WidgetTester tester, String place) async {
    GoRouter.of(tester.element(find.byType(EmberSidebar))).go(place);
    await tester.pumpAndSettle();
  }

  Future<void> named(WidgetTester tester) =>
      expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

  final places = [
    EmberRoutes.library,
    EmberRoutes.item(_video.canonicalUrl),
    EmberRoutes.playlists,
    EmberRoutes.channels,
    for (final pane in EmberSettingsPane.values) pane.route,
  ];
  for (final place in places) {
    testWidgets('**the guard**: every control has a name, $place', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      await go(tester, place);
      await named(tester);
      semantics.dispose();
    });
  }

  final layers = <String, Future<void> Function(WidgetTester)>{
    'the add dialog': (tester) => tester.tap(byLabel('Add link')),
    'the downloads panel': (tester) => tester.tap(byLabel('Downloads')),
    // The side panel shows its transcript by default, beside every place.
    'the side panel, up next': (tester) => tester.tap(find.text('Up next')),
    'the side panel, details': (tester) => tester.tap(find.text('Details')),
    'the search': (tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    },
    'the shortcuts sheet': (tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    },
    'the small window': (tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    },
  };
  for (final MapEntry(key: name, value: openIt) in layers.entries) {
    testWidgets('**the guard**: every control has a name, $name', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      await openIt(tester);
      await tester.pumpAndSettle();
      await named(tester);
      semantics.dispose();
    });
  }

  /// The part of the window [node] is in, by the order it was given.
  double? regionOf(FocusNode? node) {
    final order = node?.context
        ?.findAncestorWidgetOfExactType<FocusTraversalOrder>()
        ?.order;
    return order is NumericFocusOrder ? order.order : null;
  }

  for (final arabic in [false, true]) {
    testWidgets('**the guard**: Tab goes through the window part by part: '
        'places, the bar, the content, the panel, the player'
        '${arabic ? ', in Arabic' : ''}', (tester) async {
      if (arabic) ShellHarness.useArabic(tester);
      await open(tester);
      final visited = <double?>[];
      for (var i = 0; i < 90; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final region = regionOf(FocusManager.instance.primaryFocus);
        if (visited.isEmpty || visited.last != region) visited.add(region);
      }
      final cycle = [
        for (final r in [
          EmberRegion.sidebar,
          EmberRegion.contentBar,
          EmberRegion.content,
          EmberRegion.panel,
          EmberRegion.playerBar,
        ])
          r.index.toDouble(),
      ];
      // Wherever it starts, each part comes once, whole, in its turn.
      final start = cycle.indexOf(visited.first!);
      expect(visited, [
        for (var i = 0; i < visited.length; i++)
          cycle[(start + i) % cycle.length],
      ]);
      expect(visited.length, greaterThan(cycle.length));
    });
  }

  testWidgets('**the guard**: the menu key and Shift+F10 open the menu of a '
      'card', (tester) async {
    await open(tester);
    for (final keys in [
      [LogicalKeyboardKey.contextMenu],
      [LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.f10],
    ]) {
      // Tab to the card.
      for (var i = 0; i < 90; i++) {
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused?.findAncestorWidgetOfExactType<LibraryItemView>() != null) {
          break;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      for (final key in keys) {
        await tester.sendKeyDownEvent(key);
      }
      for (final key in keys.reversed) {
        await tester.sendKeyUpEvent(key);
      }
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget, reason: '$keys');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  });

  testWidgets("**the guard**: with Windows' high contrast on, every rule and "
      'border is drawn twice as thick; off, as thin as ever', (tester) async {
    for (final on in [false, true]) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(highContrast: on);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await open(tester);
      final context = tester.element(find.byType(EmberSidebar));
      expect(MTThemeX.of(context).hairline, on ? 2 : 1);
      expect(Theme.of(context).dividerTheme.thickness, on ? 2 : 1);
    }
  });

  testWidgets("**the guard**: with Windows' animations off, nothing moves: "
      'each change is drawn in one frame, and a playing clip does not sway', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await open(tester);
    Future<void> still(String what) async {
      await tester.pump();
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: what);
    }

    h.player.showPlaying([_video]);
    await still('a clip playing');
    await go(tester, EmberRoutes.playlists);
    await still('another place');
    // Wide enough for the wide sidebar and its button.
    ShellHarness.useWindow(tester, const Size(1920, 1080));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collapse sidebar'));
    await still('the sidebar narrowed');
    h.player.showPlaying([_video], playing: false);
    await tester.pumpAndSettle();
  });
}
