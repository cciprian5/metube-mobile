import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/platform/window_placement.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/ember_shell.dart';
import 'package:metube_desktop/shell/player_bar.dart';
import 'package:metube_desktop/shell/shell_metrics.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:metube_desktop/shell/ui_zoom.dart';
import 'package:mt_core/mt_core.dart';

import 'support/shell_harness.dart';

/// What is left above the taskbar on a 1366x768 laptop at Windows' 125%.
const _laptop = Size(1093, 566);

void main() {
  group('which sizes fit', () {
    test('the six steps, 100% in the middle', () {
      expect(uiZoomSteps, [0.8, 0.9, 1.0, 1.1, 1.25, 1.5]);
    });

    test('the laptop gets 90%, the largest that fits', () {
      expect(zoomFits(1.0, _laptop), isFalse);
      expect(fittingZoom(1.0, _laptop), 0.9);
      expect(minimumWindowAt(0.9), const Size(864, 540));
    });

    test('150% does not fit a 1280x752 work area; 125% does', () {
      expect(zoomFits(1.5, const Size(1280, 752)), isFalse);
      expect(zoomFits(1.25, const Size(1280, 752)), isTrue);
    });

    test('a screen nothing fits gets the smallest step', () {
      expect(fittingZoom(1.0, const Size(600, 400)), 0.8);
    });

    test('an unknown screen holds nothing back', () {
      expect(zoomFits(1.5, null), isTrue);
      expect(fittingZoom(1.25, null), 1.25);
    });

    test('a window is on the screen it overlaps most', () {
      const left = Rect.fromLTWH(0, 0, 1920, 1040);
      const right = Rect.fromLTWH(1920, 0, 1093, 566);
      expect(
        workAreaHolding(const Rect.fromLTWH(1800, 0, 1000, 600), [left, right]),
        right,
      );
      expect(
        workAreaHolding(const Rect.fromLTWH(-5000, 0, 10, 10), [left]),
        isNull,
      );
    });
  });

  group('the saved size', () {
    test('round trip, and anything unknown reads as 100%', () async {
      final store = MemoryKeyValueStore();
      final zooms = UiZoomStore(store: store, mutex: PrefsMutex());
      expect(await zooms.read(), 1.0);
      await zooms.write(1.25);
      expect(await zooms.read(), 1.25);
      for (final junk in ['0.85', 'big', '']) {
        await store.setString(UiZoomStore.key, junk);
        expect(await zooms.read(), 1.0, reason: junk);
      }
    });
  });

  group('in the window', () {
    Future<ShellHarness> open(
      WidgetTester tester, {
      UiZoom zoom = const UiZoom(1.0),
      Size? workArea = const Size(1920, 1040),
      Size window = const Size(1440, 900),
    }) async {
      ShellHarness.useWindow(tester, window);
      final h = ShellHarness(zoom: zoom, workArea: workArea);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      return h;
    }

    Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    Size shell(WidgetTester tester) => tester.getSize(find.byType(EmberShell));

    testWidgets('at 100% nothing changes', (tester) async {
      await open(tester);
      expect(shell(tester), const Size(1440, 900));
    });

    testWidgets('at 125% the app is laid out smaller and scaled up', (
      tester,
    ) async {
      await open(tester, zoom: const UiZoom(1.25));
      expect(shell(tester), const Size(1152, 720));
      // The column rules read the width after the zoom: 1152 narrows the
      // sidebar, where 1440 would not.
      expect(
        tester.getSize(find.byType(EmberSidebar)).width,
        EmberShellSize.sidebarNarrow,
      );
    });

    testWidgets('Ctrl+= and Ctrl+- step, Ctrl+0 resets; each is kept', (
      tester,
    ) async {
      final h = await open(tester);
      await ctrl(tester, LogicalKeyboardKey.equal);
      expect(shell(tester), const Size(1440 / 1.1, 900 / 1.1));
      expect(await h.store.getString(UiZoomStore.key), '1.1');
      expect(h.controls.calls, contains('minimum 1056x660'));

      await ctrl(tester, LogicalKeyboardKey.minus);
      await ctrl(tester, LogicalKeyboardKey.minus);
      expect(await h.store.getString(UiZoomStore.key), '0.9');

      await ctrl(tester, LogicalKeyboardKey.digit0);
      expect(shell(tester), const Size(1440, 900));
    });

    testWidgets('changing the size keeps the app as it was', (tester) async {
      await open(tester);
      final before = tester.state(find.byType(EmberShell));
      await ctrl(tester, LogicalKeyboardKey.equal);
      await ctrl(tester, LogicalKeyboardKey.digit0);
      expect(tester.state(find.byType(EmberShell)), same(before));
    });

    testWidgets('the shortcuts go by key, so an Arabic keyboard works', (
      tester,
    ) async {
      final h = await open(tester);
      // The keys stand where = and 0 are on a US keyboard but type other
      // characters, as on other layouts; only the place counts.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(
        LogicalKeyboardKey.keyQ,
        physicalKey: PhysicalKeyboardKey.equal,
      );
      expect(await h.store.getString(UiZoomStore.key), '1.1');
      await tester.sendKeyEvent(
        LogicalKeyboardKey.keyP,
        physicalKey: PhysicalKeyboardKey.digit0,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(await h.store.getString(UiZoomStore.key), '1.0');
    });

    testWidgets('**the guard**: a size that does not fit is refused', (
      tester,
    ) async {
      final h = await open(
        tester,
        zoom: const UiZoom(1.25),
        workArea: const Size(1280, 752),
        window: const Size(1280, 752),
      );
      await ctrl(tester, LogicalKeyboardKey.equal);
      expect(shell(tester), const Size(1280 / 1.25, 752 / 1.25));
      expect(await h.store.getString(UiZoomStore.key), isNull);
    });

    testWidgets('carried to a smaller screen, it steps down and says so', (
      tester,
    ) async {
      final h = await open(tester);
      h.controls.workArea.value = _laptop;
      await tester.pumpAndSettle();
      expect(await h.store.getString(UiZoomStore.key), '0.9');
      expect(h.controls.calls, contains('minimum 864x540'));
      expect(
        find.text('The interface is now 90% so it fits this screen.'),
        findsOneWidget,
      );

      // Its button opens the setting.
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EmberSidebar>(find.byType(EmberSidebar)).current,
        EmberPlace.settings,
      );
    });

    testWidgets('opened at a size chosen for this screen, it says so once', (
      tester,
    ) async {
      await open(
        tester,
        zoom: const UiZoom(0.9, lowered: true),
        workArea: _laptop,
        window: _laptop,
      );
      expect(
        find.text('The interface is now 90% so it fits this screen.'),
        findsOneWidget,
      );
      // The reason for it all: the player bar stays above the taskbar.
      expect(
        tester.getRect(find.byType(EmberPlayerBar)).bottom,
        lessThanOrEqualTo(_laptop.height),
      );
    });
  });
}
