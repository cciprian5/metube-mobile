import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/volume.dart';
import 'package:metube_desktop/shell/keyboard.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'support/shell_harness.dart';

PlaylistItem _clip(String id) => PlaylistItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: id,
  uploader: 'Field Notes',
);

void main() {
  group('which key is which', () {
    KeyDownEvent down(
      LogicalKeyboardKey logical,
      PhysicalKeyboardKey physical, [
      String? character,
    ]) => KeyDownEvent(
      logicalKey: logical,
      physicalKey: physical,
      character: character,
      timeStamp: Duration.zero,
    );

    test('**the guard**: R, F and "?" go by the key\'s place, so an Arabic '
        'layout works too', () {
      // R on an Arabic layout types the letter qaf (U+0642).
      final arabicR = down(
        const LogicalKeyboardKey(0x0642),
        PhysicalKeyboardKey.keyR,
        'ق',
      );
      expect(
        emberKeyFor(arabicR, control: false, shift: false),
        EmberKey.repeat,
      );
      final arabicF = down(
        const LogicalKeyboardKey(0x0628),
        PhysicalKeyboardKey.keyF,
      );
      expect(
        emberKeyFor(arabicF, control: true, shift: false),
        EmberKey.search,
      );
      final question = down(
        const LogicalKeyboardKey(0x061F),
        PhysicalKeyboardKey.slash,
        '؟',
      );
      expect(
        emberKeyFor(question, control: false, shift: true),
        EmberKey.shortcuts,
      );
      // Ctrl with another letter is someone else's.
      expect(emberKeyFor(arabicR, control: true, shift: false), isNull);
    });
  });

  group('over the window', () {
    Future<ShellHarness> open(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) async {
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
      final h = ShellHarness(library: const [], overrides: overrides);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('**the guard**: Space plays and pauses a clip; with none, it '
        'does nothing', (tester) async {
      final h = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(h.player.calls, isEmpty);
      h.player.showPlaying([_clip('a')]);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(h.player.calls, ['pause']);
    });

    testWidgets('**the guard**: ← and → move ten seconds, never before the '
        'start', (tester) async {
      final h = await open(tester);
      h.player
        ..showPlaying([_clip('a')])
        ..position = const Duration(seconds: 25);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(h.player.sought, const Duration(seconds: 35));
      h.player.position = const Duration(seconds: 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(h.player.sought, Duration.zero);
    });

    testWidgets('**the guard**: ↑ and ↓ change the volume, and it is kept', (
      tester,
    ) async {
      final volume = HeldVolume(50);
      final h = await open(
        tester,
        overrides: [volumeControlProvider.overrideWithValue(volume)],
      );
      h.player.showPlaying([_clip('a')]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(volume.level, 55);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(volume.level, 45);
      expect(await h.store.getInt(VolumeLevel.key), 45);
    });

    testWidgets('**the guard**: typing in a field types, it does not play', (
      tester,
    ) async {
      final h = await open(tester);
      h.player.showPlaying([_clip('a')]);
      GoRouter.of(tester.element(find.byType(EmberSidebar)))
          .go('/settings/network');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(h.player.calls, isEmpty);
      expect(h.player.sought, isNull);
    });

    testWidgets('R goes round the repeat modes, as the button does', (
      tester,
    ) async {
      final h = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      expect(h.player.calls, ['mode repeatOne']);
    });

    testWidgets('"?" opens the sheet of every key, and a dialog above stops '
        'the keys', (tester) async {
      final h = await open(tester);
      h.player.showPlaying([_clip('a')]);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.text('Play or pause'), findsOneWidget);
      // The sheet is a dialog: Space is not the player's while it is open.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(h.player.calls, isEmpty);
    });

    testWidgets('Ctrl+F opens the search', (tester) async {
      await open(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Search titles and what was said…'), findsWidgets);
    });
  });
}
