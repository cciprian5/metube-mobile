import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/incoming_links.dart';
import 'package:metube_desktop/features/settings/browser_button.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

/// The browser button: a bookmark that sends the page's link to the add
/// dialog. Settings › Desktop opens a page to drag it from, or copies it.
void main() {
  test('**the guard**: what the button makes is what the app reads, the '
      'link whole', () {
    // What the bookmark's script does, encodeURIComponent included.
    const page = 'https://www.youtube.com/watch?v=MfDROnE8FG8&t=42';
    expect(browserButtonCode, contains("'metube://add?url='"));
    expect(browserButtonCode, contains('encodeURIComponent(location.href)'));
    expect(
      linkFromProtocol('metube://add?url=${Uri.encodeComponent(page)}'),
      page,
    );
  });

  test('the setup page carries the button to drag, in the language and '
      'direction of the app, and its colours', () async {
    final ar = await MTLocalizations.delegate.load(const Locale('ar'));
    final html = browserButtonPage(ar, MTPalette.superDay, rtl: true);
    expect(html, contains('dir="rtl"'));
    expect(html, contains(ar.desktopBrowserPageTitle));
    expect(html, contains('>${ar.desktopBrowserButtonName}</a>'));
    // The link keeps its quotes inside the attribute's own.
    expect(
      html,
      contains(
        'href="javascript:location.href=\'metube://add?url=\''
        '+encodeURIComponent(location.href)"',
      ),
    );
    final accent = (MTPalette.superDay.accent.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    expect(html, contains('#$accent'));
    final en = await MTLocalizations.delegate.load(const Locale('en'));
    expect(
      browserButtonPage(en, MTPalette.superNight, rtl: false),
      contains('dir="ltr"'),
    );
  });

  testWidgets('Settings › Desktop offers the page and copies the code', (
    tester,
  ) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final copied = <String>[];
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
    final h = ShellHarness(library: const []);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go('/settings/desktop');
    await tester.pumpAndSettle();
    expect(find.text('“To Ember” button in the browser'), findsOneWidget);
    expect(find.text('Open the setup page'), findsOneWidget);
    await tester.tap(find.text('Copy the code'));
    await tester.pumpAndSettle();
    expect(copied, [browserButtonCode]);
    expect(find.textContaining('Code copied'), findsOneWidget);
  });
}
