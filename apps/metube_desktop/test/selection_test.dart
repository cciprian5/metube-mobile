import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/features/library/selection.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

LibraryItem _clip(String id, String title) => LibraryItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: title,
  onServer: true,
  isAudio: true,
  timestamp: DateTime(2026, 10, 20),
);

final _library = [
  _clip('aaaaaaaaaaa', 'Amber Skies'),
  _clip('bbbbbbbbbbb', 'Blue Hour'),
  _clip('ccccccccccc', 'Cedar Trail'),
  _clip('ddddddddddd', 'Dune Song'),
];

void main() {
  Future<ShellHarness> open(WidgetTester tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: _library,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  Finder card(String title) => find
      .descendant(of: find.byType(MTMediaGridCard), matching: find.text(title))
      .first;

  Future<void> click(WidgetTester tester, String title) async {
    await tester.tap(card(title), kind: PointerDeviceKind.mouse);
    // Past a double click's window, so the next click starts afresh.
    await tester.runAsync(
      () => Future<void>.delayed(
        kDoubleTapTimeout + const Duration(milliseconds: 50),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('**the guard**: a click chooses and does not play; a double '
      'click plays', (tester) async {
    final h = await open(tester);
    await click(tester, 'Blue Hour');
    expect(h.player.calls, isEmpty);
    expect(find.text('1 selected'), findsOneWidget);

    await doubleClick(tester, card('Cedar Trail'));
    await tester.pumpAndSettle();
    expect(h.player.calls, contains('playItems'));
  });

  testWidgets('Ctrl adds one, Shift takes the run, Esc lets go', (
    tester,
  ) async {
    await open(tester);
    await click(tester, 'Amber Skies');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await click(tester, 'Cedar Trail');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await click(tester, 'Dune Song');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    // From the last one chosen (Cedar Trail) to Dune Song.
    expect(find.text('2 selected'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('Ctrl+A takes every clip shown', (tester) async {
    await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('4 selected'), findsOneWidget);
  });

  testWidgets('deleting the chosen clips asks once, then goes by each one\'s '
      'canonical link', (tester) async {
    final h = await open(tester);
    await click(tester, 'Amber Skies');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await click(tester, 'Blue Hour');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(byLabel('Delete From Server'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete 2 clips'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(h.api.deleted, [
      ['https://youtu.be/aaaaaaaaaaa'],
      ['https://youtu.be/bbbbbbbbbbb'],
    ]);
  });

  test('**the guard**: Enter and a screen reader play, as they always did; '
      'only a mouse click chooses', () {
    // No button went down: the keyboard or a screen reader.
    expect(ClickClock.activate('x'), ClickMeaning.play);
    ClickClock.pointerDown();
    expect(ClickClock.activate('y'), ClickMeaning.choose);
    ClickClock.pointerDown();
    expect(ClickClock.activate('y'), ClickMeaning.play);
  });
}
