import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/features/clip/clip_state.dart';
import 'package:metube_desktop/features/clip/video_controls.dart';
import 'package:metube_desktop/features/library/library_item_view.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/player_controls.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

const _url = 'https://youtu.be/aaaaaaaaaaa';

final _clip = LibraryItem(
  canonicalUrl: _url,
  title: 'Night Drive',
  uploader: 'Field Notes',
  onServer: true,
  serverFilename: 'Night Drive.mkv',
  sizeBytes: 412 * 1024 * 1024,
  timestamp: DateTime(2026, 10, 20),
);

final _other = LibraryItem(
  canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
  title: 'Amber Skies',
  onServer: true,
  isAudio: true,
  timestamp: DateTime(2026, 10, 19),
);

Finder _control(String label) =>
    find.byWidgetPredicate((w) => w is EmberPlayerControl && w.label == label);

void main() {
  late List<String> copied;

  Future<ShellHarness> open(WidgetTester tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    copied = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = ShellHarness(
      library: [_clip, _other],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(EmberSidebar)));

  Finder card(String title) => find.descendant(
    of: find.byType(LibraryItemView),
    matching: find.text(title),
  );

  Future<void> rightClick(WidgetTester tester, Finder on) async {
    await tester.tapAt(
      tester.getCenter(on.first),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  group('the right-click menu', () {
    testWidgets('**the guard**: "play next" queues the clip after what plays '
        'and leaves it playing', (tester) async {
      final h = await open(tester);
      h.player.showPlaying([toPlaylistItem(_other)], playing: false);
      await tester.pumpAndSettle();
      await rightClick(tester, card('Night Drive'));
      await tester.tap(find.text('Play next'));
      await tester.pumpAndSettle();
      expect(h.player.calls, ['next Night Drive']);
      expect(find.text('Plays next, after this one'), findsOneWidget);
    });

    testWidgets('it plays, opens the reading room and marks a favourite, '
        'each with its key beside it', (tester) async {
      final h = await open(tester);
      await rightClick(tester, card('Night Drive'));
      for (final keys in ['Enter', 'Shift Enter', 'Ctrl R', 'F', 'Ctrl C']) {
        expect(find.text(mtLtrRun(keys)), findsOneWidget, reason: keys);
      }
      await tester.tap(find.text('Add to favorites'));
      await tester.pumpAndSettle();
      final tags = await containerOf(tester)
          .read(tagsIndexProvider)
          .tagsOf(_url);
      expect(tags, contains(MTConstants.favoritesSystemTag));

      await rightClick(tester, card('Night Drive'));
      await tester.tap(find.text('Play').last);
      await tester.pumpAndSettle();
      expect(h.player.calls, contains('playItems'));

      final router = GoRouter.of(tester.element(find.byType(EmberSidebar)));
      router.go(EmberRoutes.library);
      await tester.pumpAndSettle();
      await rightClick(tester, card('Night Drive'));
      await tester.tap(find.text('Reading room').last);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        EmberRoutes.reading(_url),
      );
    });
  });

  testWidgets('**the guard**: the menu\'s keys work on a clip with focus', (
    tester,
  ) async {
    final h = await open(tester);
    final inkWell = find.descendant(
      of: find.byType(LibraryItemView).first,
      matching: find.byType(InkWell),
    );
    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.descendant(of: inkWell, matching: find.byType(Focus)),
              matching: find.byType(Semantics),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    // Shift+Enter queues it; it does not also play as Enter would.
    expect(h.player.calls, ['next Night Drive']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(copied, [_url]);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    final tags = await containerOf(tester).read(tagsIndexProvider).tagsOf(_url);
    expect(tags, contains(MTConstants.favoritesSystemTag));
  });

  group('on the clip page', () {
    Future<ShellHarness> watch(
      WidgetTester tester, {
      bool playing = false,
    }) async {
      final h = await open(tester);
      h.player.showPlaying([toPlaylistItem(_clip)], playing: playing);
      GoRouter.of(tester.element(find.byType(EmberSidebar)))
          .go(EmberRoutes.item(_url));
      await tester.pumpAndSettle();
      return h;
    }

    double shown(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(ClipVideoControls),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('paused, the picture keeps its controls; theater and full '
        'screen work from them', (tester) async {
      final h = await watch(tester);
      expect(shown(tester), 1);
      final controls = find.byType(ClipVideoControls);
      await tester.tap(
        find.descendant(of: controls, matching: _control('Theater')),
      );
      await tester.pumpAndSettle();
      expect(containerOf(tester).read(theaterProvider), isTrue);
      await tester.tap(
        find.descendant(of: controls, matching: _control('Fullscreen')),
      );
      await tester.pumpAndSettle();
      expect(h.controls.calls, contains('fullScreen true'));
      // In full screen: the way back, and no theater.
      expect(
        find.descendant(of: controls, matching: _control('Theater')),
        findsNothing,
      );
      expect(
        find.descendant(of: controls, matching: _control('Exit fullscreen')),
        findsOneWidget,
      );
    });

    testWidgets('**the guard**: playing, they come with the pointer and go '
        'when it rests', (tester) async {
      await watch(tester, playing: true);
      expect(shown(tester), 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(ClipVideoControls)));
      await tester.pumpAndSettle();
      expect(shown(tester), 1);
      await tester.pump(ClipVideoControls.linger);
      await tester.pumpAndSettle();
      expect(shown(tester), 0);
    });

    testWidgets('the facts line: the quality that plays, the format, the '
        'size and where it is kept', (tester) async {
      final h = await watch(tester);
      String facts() => tester
          .widgetList<Text>(find.textContaining('MKV'))
          .map((t) => t.data!)
          .single;
      expect(facts(), isNot(contains('p ')));
      expect(facts(), contains('412.0 MB'));
      expect(facts(), contains('On the server'));

      h.video.pictureSize.value = const Size(1920, 1080);
      await tester.pumpAndSettle();
      expect(facts(), startsWith('$mtFirstStrongIsolate${mtLtrRun('1080p')}'));
    });
  });
}
