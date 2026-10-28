import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/downloads_data.dart';
import 'package:metube_desktop/features/downloads/downloads_button.dart';
import 'package:metube_desktop/features/settings/simple_panes.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/now_playing_bars.dart';
import 'package:metube_desktop/shell/panel/queue_view.dart';
import 'package:metube_desktop/shell/player_bar.dart';
import 'package:metube_desktop/shell/player_controls.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:metube_desktop/shell/sidebar_items.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

final _clip = LibraryItem(
  canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
  title: 'Amber Skies',
  onServer: true,
  isAudio: true,
  timestamp: DateTime(2026, 10, 20),
);

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MTDesktopApp(
      child: MaterialApp(
        theme: mtDesktopTheme(MTVariant.superApp, brightness),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  test('**the guard**: hovering veils a control, never covers it', () {
    for (final b in Brightness.values) {
      final theme = mtDesktopTheme(MTVariant.superApp, b);
      expect(theme.hoverColor.a, lessThan(0.5), reason: '$b');
      final hovered = theme.iconButtonTheme.style!.overlayColor!.resolve({
        WidgetState.hovered,
      })!;
      expect(hovered.a, lessThan(0.5), reason: '$b');
    }
  });

  testWidgets('**the guard**: two neighbouring controls\' marks never touch', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmberPlayerControl(icon: MTIcons.prev, label: 'a', onTap: () {}),
            EmberPlayerControl(icon: MTIcons.next, label: 'b', onTap: () {}),
          ],
        ),
      ),
    );
    final buttons = find.byType(IconButton);
    final a = tester.getRect(buttons.at(0));
    final b = tester.getRect(buttons.at(1));
    expect(b.left - a.right, greaterThan(0));
  });

  testWidgets('**the guard**: each play mode has its own glyph, and on is '
      'filled', (tester) async {
    expect(
      {for (final m in PlayMode.values) playModeIcon(m)},
      hasLength(3),
      reason: 'repeat one and stop after differ from repeat',
    );
    await tester.pumpWidget(
      _host(
        EmberPlayerControl(
          icon: MTIcons.repeatOne,
          label: 'Repeat One',
          selected: true,
          onTap: () {},
        ),
      ),
    );
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.style?.backgroundColor?.resolve({}), isNotNull);
  });

  testWidgets('**the guard**: the downloads count sits off the arrow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeDownloadsProvider.overrideWithValue(3)],
        child: _host(const DownloadsButton()),
      ),
    );
    final glyph = tester.getRect(find.byType(MTIcon));
    final count = tester.getRect(find.text('3'));
    final overlap = glyph.intersect(count);
    expect(
      overlap.isEmpty ||
          overlap.width * overlap.height < 0.2 * glyph.width * glyph.height,
      isTrue,
    );
  });

  testWidgets('**the guard**: the sidebar narrows by a glyph alone', (
    tester,
  ) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(library: [_clip]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final toggle = find.byType(SidebarToggle);
    expect(toggle, findsOneWidget);
    expect(
      find.descendant(of: toggle, matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(EmberSidebar),
        matching: find.text('Collapse sidebar'),
      ),
      findsNothing,
    );
  });

  testWidgets('**the guard**: the clip playing in the queue sways', (
    tester,
  ) async {
    final player = FakePlayer()
      ..showPlaying([toPlaylistItem(_clip)], playing: false);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 340,
          height: 400,
          child: QueueView(state: player.state, player: player),
        ),
      ),
    );
    expect(find.byType(NowPlayingBars), findsOneWidget);
  });

  testWidgets('**the guard**: the layouts and the figures are glyphs, '
      'named under the mouse', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: [_clip],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    for (final name in ['Grid', 'Table', 'Compact', 'Statistics']) {
      expect(find.text(name), findsNothing, reason: name);
      expect(find.bySemanticsLabel(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('**the guard**: a notice on the computer is a corner card '
      'above the player bar', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(library: [_clip]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    showMTNotice(
      tester.element(find.byType(EmberPlayerBar)),
      message: 'Volume 100%',
    );
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byType(MTNotice));
    final bar = tester.getRect(find.byType(EmberPlayerBar));
    expect(card.width, lessThanOrEqualTo(MTNotice.desktopWidth));
    expect(card.bottom, lessThanOrEqualTo(bar.top));
    expect(card.overlaps(tester.getRect(find.byType(EmberSidebar))), isFalse);
  });

  testWidgets('**the guard**: in Arabic the notice keeps off the sidebar '
      'too, in the opposite corner', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    ShellHarness.useArabic(tester);
    final h = ShellHarness(library: [_clip]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    showMTNotice(
      tester.element(find.byType(EmberPlayerBar)),
      message: 'الصوت 100%',
    );
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byType(MTNotice));
    expect(card.overlaps(tester.getRect(find.byType(EmberSidebar))), isFalse);
    expect(card.left, lessThan(900 / 2));
  });

  testWidgets('**the guard**: a setting\'s switch is at the line\'s far end, '
      'with a hairline under the line', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 640,
          child: SwitchLine(
            title: 'Start with Windows',
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final line = tester.getRect(find.byType(SettingLine));
    final control = tester.getRect(find.byType(MTSwitch));
    expect(line.right - control.right, lessThan(1));
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SettingLine),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).border, isNotNull);
  });

  testWidgets('**the guard**: moving between settings sections keeps the '
      'page, so only the section changes', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(library: [_clip]);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(EmberSidebar)));
    router.go(EmberSettingsPane.appearance.route);
    await tester.pumpAndSettle();
    final list = tester.state(find.byType(Scrollable).first);
    router.go(EmberSettingsPane.about.route);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(Scrollable).first), same(list));
  });
}
