import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/panel_reveal.dart';
import 'package:metube_desktop/features/downloads/downloads_button.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/settings/about_pane.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/content_bar.dart';
import 'package:metube_desktop/shell/ember_mark.dart';
import 'package:metube_desktop/shell/right_panel.dart';
import 'package:metube_desktop/shell/shell_metrics.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:metube_desktop/shell/sidebar_items.dart';
import 'package:metube_desktop/shell/title_bar.dart';
import 'package:metube_desktop/shell/ui_zoom.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

/// The window's one bar: the title bar carries back, search, downloads
/// and the two toggles, and every bare bit of it still moves the window.
void main() {
  Future<ShellHarness> open(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    bool arabic = false,
    double zoom = 1.0,
  }) async {
    ShellHarness.useWindow(tester, size);
    if (arabic) ShellHarness.useArabic(tester);
    final h = ShellHarness(library: const [], zoom: UiZoom(zoom));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  Finder tip(String en, String ar) => find.byWidgetPredicate(
    (w) => w is MTShortcutTooltip && (w.message == en || w.message == ar),
  );
  final panelButton = tip('Hide side panel', 'إخفاء اللوحة الجانبية');

  for (final arabic in [false, true]) {
    final lang = arabic ? ', in Arabic' : '';

    testWidgets('**the guard**: one bar: the tools sit in the title bar, and '
        'the sidebar starts right under it$lang', (tester) async {
      await open(tester, arabic: arabic);
      final bar = find.byType(EmberTitleBar);
      expect(
        find.descendant(of: bar, matching: find.byType(EmberContentBar)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(DownloadsButton)),
        findsOneWidget,
      );
      expect(tester.getSize(bar).height, EmberShellSize.titleBar);
      expect(
        tester.getTopLeft(find.byType(EmberSidebar)).dy,
        EmberShellSize.titleBar,
      );
    });

    testWidgets('**the guard**: the sidebar toggle stands over the sidebar, '
        "the panel's button over the panel$lang", (tester) async {
      await open(tester, arabic: arabic);
      final sidebar = tester.getRect(find.byType(EmberSidebar));
      final toggle = tester.getCenter(find.byType(SidebarToggle));
      expect(toggle.dx, inInclusiveRange(sidebar.left, sidebar.right));
      final panel = tester.getRect(find.byType(EmberRightPanel));
      final button = tester.getCenter(panelButton);
      expect(button.dx, inInclusiveRange(panel.left, panel.right));
    });

    testWidgets('**the guard**: the bare bar moves the window and a double '
        'click on it maximizes; a tool does neither and answers at once'
        '$lang', (tester) async {
      final h = await open(tester, arabic: arabic);
      // Between the search box and the downloads: bare bar.
      final search = tester.getRect(
        find
            .ancestor(
              of: find.text(
                arabic
                    ? 'ابحث في العناوين وما قيل…'
                    : 'Search titles and what '
                          'was said…',
              ),
              matching: find.byType(Material),
            )
            .first,
      );
      final downloads = tester.getRect(find.byType(DownloadsButton));
      final bare = Offset(
        arabic
            ? (downloads.right + search.left) / 2
            : (search.right + downloads.left) / 2,
        EmberShellSize.titleBar / 2,
      );
      await tester.dragFrom(bare, const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(h.controls.calls, contains('startDragging'));

      h.controls.calls.clear();
      await tester.tapAt(bare);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(bare);
      await tester.pumpAndSettle();
      expect(h.controls.calls, ['toggleMaximize']);

      // A click on a tool takes effect on the frame it ends, not after a
      // wait to learn whether a second click follows.
      h.controls.calls.clear();
      await tester.tap(panelButton);
      await tester.pump();
      // Closing on this very frame: the panel is on its way out.
      expect(
        tester.widget<PanelReveal>(find.byType(PanelReveal).first).shown,
        isFalse,
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmberRightPanel), findsNothing);
      expect(h.controls.calls, isEmpty);
    });
  }

  testWidgets("**the guard**: the app's mark stands in the title bar, the "
      'small cut there, and the full one beside the name in About', (
    tester,
  ) async {
    await open(tester);
    final inBar = find.descendant(
      of: find.byType(EmberTitleBar),
      matching: find.byType(EmberMark),
    );
    expect(inBar, findsOneWidget);
    expect(tester.getSize(inBar).width, lessThan(EmberMark.smallBelow));

    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberSettingsPane.about.route);
    await tester.pumpAndSettle();
    final inAbout = find.descendant(
      of: find.byType(AboutPane),
      matching: find.byType(EmberMark),
    );
    expect(inAbout, findsOneWidget);
    expect(
      tester.getSize(inAbout).width,
      greaterThanOrEqualTo(EmberMark.smallBelow),
    );
  });

  testWidgets('**the guard**: given room the search is a box; cramped, a '
      'button that still opens it', (tester) async {
    await open(tester);
    expect(find.text('Search titles and what was said…'), findsOneWidget);

    await open(tester, size: const Size(960, 600), zoom: 1.5);
    expect(find.text('Search titles and what was said…'), findsNothing);
    final button = tip('Search', 'البحث');
    expect(
      find.descendant(of: find.byType(EmberContentBar), matching: button),
      findsOneWidget,
    );
  });
}
