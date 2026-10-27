import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/pill.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

/// What the Arabic window must get right with a Latin title in it.
void main() {
  final clip = LibraryItem(
    canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
    title: 'Video by mohamed.abdou90',
    onServer: true,
    serverFilename: 'clip.mp4',
    timestamp: DateTime(2026, 10, 20),
  );

  Future<void> open(WidgetTester tester, String route) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    ShellHarness.useArabic(tester);
    final h = ShellHarness(
      library: [clip],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.player.showPlaying([toPlaylistItem(clip)], playing: false);
    GoRouter.of(tester.element(find.byType(EmberSidebar))).go(route);
    await tester.pumpAndSettle();
  }

  testWidgets('**the guard**: a Latin title keeps its own direction and '
      'sits on the Arabic side, on the clip page and in the side panel', (
    tester,
  ) async {
    await open(tester, EmberRoutes.item(clip.canonicalUrl));
    final titles = tester
        .widgetList<Text>(find.text(clip.title))
        .where((t) => t.maxLines != 1);
    expect(titles, isNotEmpty);
    for (final t in titles) {
      expect(t.textDirection, TextDirection.ltr);
      expect(t.textAlign, TextAlign.right);
    }
  });

  testWidgets('**the guard**: "back to the clip" points right in Arabic', (
    tester,
  ) async {
    await open(tester, EmberRoutes.reading(clip.canonicalUrl));
    final back = find.widgetWithText(EmberPill, 'العودة إلى المقطع');
    final flip = tester.widget<Transform>(
      find.descendant(of: back, matching: find.byType(Transform)).first,
    );
    expect(flip.transform.entry(0, 0), -1);
  });
}
