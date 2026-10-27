import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

void main() {
  testWidgets('**the guard**: a search field\'s magnifier is drawn at the '
      'size of the window\'s search box, not grown to fill its slot', (
    tester,
  ) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      overrides: [
        // Logs reads its file; one that is never written is enough here.
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/ember_none.log'),
        ),
      ],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberSettingsPane.logs.route);
    await tester.pumpAndSettle();
    final lens = find.descendant(
      of: find.byType(TextField),
      matching: find.byWidgetPredicate(
        (w) => w is MTIcon && w.icon == MTIcons.search,
      ),
    );
    expect(lens, findsOneWidget);
    expect(tester.getSize(lens).width, MTSpace.lg);
  });
}
