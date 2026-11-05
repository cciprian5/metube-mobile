import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/desktop_habits.dart';
import 'package:metube_desktop/platform/startup.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

void main() {
  Future<ShellHarness> open(
    WidgetTester tester,
    List<Override> overrides,
  ) async {
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
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go('/settings/desktop');
    await tester.pumpAndSettle();
    return h;
  }

  MTSwitch switchOf(WidgetTester tester, String title) =>
      tester.widget<MTSwitch>(
        find.descendant(
          of: find
              .ancestor(of: find.text(title), matching: find.byType(Row))
              .first,
          matching: find.byType(MTSwitch),
        ),
      );

  Future<void> flip(WidgetTester tester, String title) async {
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(of: find.text(title), matching: find.byType(Row))
            .first,
        matching: find.byType(MTSwitch),
      ),
    );
    await tester.pumpAndSettle();
  }

  const playKey = 'Play and pause from any app';
  const startUp = 'Start with Windows';

  testWidgets('**the guard**: the play key is off until chosen, asks '
      'Windows, and is kept', (tester) async {
    final asked = <bool>[];
    final h = await open(tester, [
      globalPlayKeyHookProvider.overrideWithValue((on) async {
        asked.add(on);
        return true;
      }),
    ]);
    expect(switchOf(tester, playKey).value, isFalse);
    expect(find.textContaining('Ctrl+Alt+Space'), findsOneWidget);
    await flip(tester, playKey);
    expect(asked, [true]);
    expect(switchOf(tester, playKey).value, isTrue);
    expect(await h.store.getBool(GlobalPlayKey.key), isTrue);
  });

  testWidgets('**the guard**: a combination another app holds leaves the '
      'switch off and says so', (tester) async {
    final h = await open(tester, [
      globalPlayKeyHookProvider.overrideWithValue((on) async => false),
    ]);
    await flip(tester, playKey);
    expect(switchOf(tester, playKey).value, isFalse);
    expect(await h.store.getBool(GlobalPlayKey.key), isNull);
    expect(
      find.text('Another app already uses Ctrl+Alt+Space.'),
      findsOneWidget,
    );
  });

  testWidgets('**the guard**: start with Windows follows what Windows says, '
      'and a refusal leaves it as it was', (tester) async {
    var windowsSays = true;
    await open(tester, [
      initialStartWithWindowsProvider.overrideWithValue(true),
      startWithWindowsHookProvider.overrideWithValue((on) async => windowsSays),
    ]);
    // On already, because Windows' start-up list has the app.
    expect(switchOf(tester, startUp).value, isTrue);
    windowsSays = false;
    await flip(tester, startUp);
    expect(switchOf(tester, startUp).value, isTrue);
    expect(
      find.text('Windows did not let the app start with it.'),
      findsOneWidget,
    );
    windowsSays = true;
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await flip(tester, startUp);
    expect(switchOf(tester, startUp).value, isFalse);
  });

  test('**the guard**: started with Windows, the window is not shown by the '
      "runner's first-frame fallback: it looks for the same argument", () {
    final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();
    expect(runner, contains('L"${WindowsStartup.arg}"'));
  });
}
