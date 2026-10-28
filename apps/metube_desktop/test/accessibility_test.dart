import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart'
    show Brightness, InkWell, MaterialApp, TextField, Theme;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/shell/sidebar_items.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/features/folders/folder_widgets.dart';
import 'package:metube_desktop/features/library/library_item_view.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/focus_regions.dart';
import 'package:metube_desktop/shell/now_playing.dart';
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
  Future<ShellHarness> open(
    WidgetTester tester, {
    Size window = const Size(1440, 900),
  }) async {
    ShellHarness.useWindow(tester, window);
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
    EmberRoutes.reading(_video.canonicalUrl),
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

  // Narrow, the sidebar shows icons alone, whose names were only in their
  // tooltips, which say nothing to a screen reader.
  for (final place in [
    EmberRoutes.library,
    EmberRoutes.item(_video.canonicalUrl),
  ]) {
    testWidgets('**the guard**: every control has a name in a narrow '
        'window, $place', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, window: const Size(1000, 700));
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

  // Every page in the content lies over a modal barrier, which hid from a
  // screen reader all that was painted before it: the title bar, the
  // places and the bar with the search. Only the real reader showed it.
  for (final place in [EmberRoutes.library, EmberRoutes.settings]) {
    testWidgets('**the guard**: a screen reader reaches every part of the '
        'window, $place', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      await go(tester, place);
      for (final (part, label) in [
        ('title bar', 'Close'),
        ('sidebar', 'Playlists'),
        ('content bar', 'Search titles and what was said…'),
        ('side panel', 'Up next'),
        ('player bar', 'Queue'),
      ]) {
        expect(find.semantics.byLabel(label), findsAny, reason: part);
      }
      semantics.dispose();
    });
  }

  testWidgets('**the guard**: the player bar tells a screen reader what each '
      'control is: play is a button, the bar reads as time, what plays opens '
      'as a button; and no tooltip ends in a stray placeholder', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Play')),
      isSemantics(isButton: true, isEnabled: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Position in the clip')),
      isSemantics(isSlider: true, value: '0:00'),
    );
    // The speed says what it is; its tooltip says nothing to a reader.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Playback speed')),
      isSemantics(isButton: true, value: mtLtrRun('1.0×')),
    );
    expect(
      tester.getSemantics(
        find
            .descendant(
              of: find.byType(EmberNowPlaying),
              matching: find.byType(InkWell),
            )
            // The clip's own; the heart beside it is a button of its own.
            .first,
      ),
      isSemantics(isButton: true),
    );
    final stray = <String>[];
    void walk(SemanticsNode node) {
      final data = node.getSemanticsData();
      if ('${data.label}${data.tooltip}'.contains('￼')) {
        stray.add('${data.label} / ${data.tooltip}');
      }
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(
      tester
          .binding
          .renderViews
          .first
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    expect(stray, isEmpty);
    semantics.dispose();
  });

  // A name and a tooltip on one node, Windows reads both: "Play. Play".
  for (final window in [const Size(1440, 900), const Size(1000, 700)]) {
    testWidgets('**the guard**: no control says its name twice, '
        '${window.width.toInt()} wide', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, window: window);
      final twice = <String>[];
      void walk(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.label.isNotEmpty && data.tooltip.isNotEmpty) {
          twice.add('${data.label} / ${data.tooltip}');
        }
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(twice, isEmpty);
      semantics.dispose();
    });
  }

  testWidgets('**the guard**: the add window keeps its link field named once '
      'filled, and its folder and the folders offered read as buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await tester.tap(byLabel('Add link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'https://youtu.be/aaaaaaaaaaa',
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(EditableText).last),
      isSemantics(isTextField: true, label: 'Add URL'),
    );
    expect(
      tester.getSemantics(find.text('Folder').last),
      isSemantics(isButton: true),
    );
    // Its list: each folder a button, the current one selected.
    await tester.tap(find.text('Folder').last);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('No folder').last),
      isSemantics(isButton: true, isSelected: true),
    );
    semantics.dispose();
  });

  testWidgets('**the guard**: the folders help is a button named by what it '
      'explains, not by its question mark', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: Center(
          child: PulsingHelp(label: 'How folders work', onTap: () {}),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(InkWell)),
      isSemantics(isButton: true, label: 'How folders work'),
    );
    semantics.dispose();
  });

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
    await tester.tap(find.byType(SidebarToggle));
    await still('the sidebar narrowed');
    h.player.showPlaying([_video], playing: false);
    await tester.pumpAndSettle();
  });
}
