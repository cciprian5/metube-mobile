import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/library/library_heading.dart';
import 'package:metube_desktop/features/library/sort_button.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

/// Enough clips to scroll well past the heading.
final _many = [
  for (var i = 0; i < 60; i++)
    LibraryItem(
      canonicalUrl: 'https://youtu.be/clip${i.toString().padLeft(6, '0')}',
      title: 'Clip number $i',
      onServer: true,
      serverFilename: 'clip$i.mp4',
      timestamp: DateTime(2026, 10, 1).add(Duration(hours: i)),
      duration: const Duration(minutes: 3),
    ),
];

void main() {
  Future<ShellHarness> library(WidgetTester tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: _many,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  Color edgeOf(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(PinnedLibraryHeading),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return ((box.decoration! as BoxDecoration).border! as Border).bottom.color;
  }

  testWidgets('**the guard**: the heading stays at the top while the '
      'library scrolls, with the table\'s titles under it', (tester) async {
    await library(tester);
    await tester.tap(find.bySemanticsLabel('Table'));
    await tester.pumpAndSettle();
    expect(edgeOf(tester).a, 0);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pumpAndSettle();

    final heading = tester.getRect(find.byType(PinnedLibraryHeading));
    final sort = tester.getRect(find.byType(SortButton));
    expect(sort.top, greaterThanOrEqualTo(heading.top));
    expect(sort.bottom, lessThanOrEqualTo(heading.bottom));
    expect(heading.top, lessThan(200));
    // The filters went with the scroll; the titles of the columns did not.
    expect(find.text('YouTube · 60').hitTestable(), findsNothing);
    final titles = tester.getRect(find.byType(MTMediaRowHeader));
    expect(titles.top, moreOrLessEquals(heading.bottom, epsilon: 1));
    // Something is under it now, so its edge shows.
    expect(edgeOf(tester).a, greaterThan(0));
  });

  testWidgets('**the guard**: a new layout fades the list in, once', (
    tester,
  ) async {
    await library(tester);
    double opacity() => tester
        .widget<SliverFadeTransition>(
          find.descendant(
            of: find.byType(SliverFadeOnChange),
            matching: find.byType(SliverFadeTransition),
          ),
        )
        .opacity
        .value;
    expect(opacity(), 1);
    await tester.tap(find.bySemanticsLabel('Table'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(opacity(), lessThan(1));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('**the guard**: from the library to a clip the page fades '
      'through, with no zoom out of a snapshot', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await library(tester);
      GoRouter.of(tester.element(find.byType(EmberSidebar)))
          .go(EmberRoutes.item(_many.first.canonicalUrl));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Windows' default zooms a snapshot of the page out of a scrim.
      expect(find.byType(SnapshotWidget), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(PinnedLibraryHeading), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
