import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/library/library_page.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/context_menu.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

List<LibraryItem> _clips(int n) => [
  for (var i = 0; i < n; i++)
    LibraryItem(
      canonicalUrl: 'https://youtu.be/clip${i.toString().padLeft(7, '0')}',
      title: 'Clip $i',
      onServer: true,
      serverFilename: 'Clip $i.mp4',
      timestamp: DateTime(2026, 11, 1).subtract(Duration(minutes: i)),
    ),
];

/// Two of the owner's notes of 2026-11-05: back from a clip the library
/// opened at its top instead of where it was left, and in the smallest
/// window the menu's last line (Delete) sat below the edge.
void main() {
  Future<ShellHarness> open(WidgetTester tester, Size window) async {
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
    final h = ShellHarness(
      library: _clips(80),
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  ScrollPosition list(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(LibraryPage),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(LibraryPage)));

  group('the place in the library', () {
    testWidgets('**the guard**: a clip opened from far down, then the '
        'library again, is back where it was left', (tester) async {
      await open(tester, const Size(1440, 900));
      list(tester).jumpTo(2400);
      await tester.pumpAndSettle();

      router(tester).go(EmberRoutes.item('https://youtu.be/clip0000030'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryPage), findsNothing);
      GoRouter.of(tester.element(find.byType(Navigator).last))
          .go(EmberRoutes.library);
      await tester.pumpAndSettle();

      expect(list(tester).pixels, 2400);
    });

    testWidgets('another view of the library is another list, and starts at '
        'the top as before', (tester) async {
      await open(tester, const Size(1440, 900));
      list(tester).jumpTo(2400);
      await tester.pumpAndSettle();

      router(tester).go(EmberRoutes.favorites);
      await tester.pumpAndSettle();
      expect(list(tester).pixels, 0);
    });
  });

  group('the menu in a short window', () {
    test('rows keep their height while the menu fits, and shorten, never '
        'under the floor, when it does not', () {
      final entries = [
        for (var i = 0; i < 13; i++) EmberMenuEntry(i, null, '$i'),
        const EmberMenuEntry<int>.divider(),
        const EmberMenuEntry<int>.divider(),
      ];
      expect(emberMenuRowHeight(entries, 900), 36);
      final short = emberMenuRowHeight(entries, 455);
      expect(short, lessThan(36));
      expect(13 * short + 2 * 16 + 4 * 8, lessThanOrEqualTo(455));
      expect(emberMenuRowHeight(entries, 200), emberMenuTightRow);
    });

    testWidgets('**the guard**: in the smallest window, Delete from server '
        'is in view without scrolling the menu', (tester) async {
      await open(tester, const Size(960, 600));
      await tester.tapAt(
        tester.getCenter(find.text('Clip 0')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final delete = find.text('Delete from server');
      expect(delete, findsOneWidget);
      final menu = tester.getRect(
        find
            .ancestor(of: delete, matching: find.byType(SingleChildScrollView))
            .first,
      );
      expect(tester.getRect(delete).bottom, lessThanOrEqualTo(menu.bottom));
    });
  });
}
