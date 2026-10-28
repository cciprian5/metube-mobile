import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/downloads_data.dart';
import 'package:metube_desktop/features/downloads/download_glyph.dart';
import 'package:metube_desktop/features/downloads/downloads_button.dart';
import 'package:mt_ui/mt_ui.dart';

/// The downloads arrow moves while anything downloads, as the phone's does,
/// and stands still otherwise.
void main() {
  Future<void> show(
    WidgetTester tester,
    int active, {
    bool still = false,
    bool motion = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDownloadsProvider.overrideWithValue(active),
          if (!motion) downloadMotionProvider.overrideWithValue(false),
        ],
        child: MTDesktopApp(
          child: MaterialApp(
            theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: still),
              child: child!,
            ),
            home: const Scaffold(body: Center(child: DownloadsButton())),
          ),
        ),
      ),
    );
    // Into the fall, where the arrow is furthest from rest.
    await tester.pump(MTDownloadsIcon.period * 0.65);
  }

  /// How far the arrow stands from rest, and how faded it is.
  (double, double) arrow(WidgetTester tester) {
    final glyph = find.byType(DownloadGlyph);
    final shift = tester
        .widget<Transform>(
          find.descendant(of: glyph, matching: find.byType(Transform)).last,
        )
        .transform
        .getTranslation()
        .y;
    final opacity = tester
        .widget<Opacity>(
          find.descendant(of: glyph, matching: find.byType(Opacity)),
        )
        .opacity;
    return (shift, opacity);
  }

  testWidgets('**the guard**: while something downloads the arrow drops '
      'and fades, the tray staying put', (tester) async {
    await show(tester, 2);
    final (shift, opacity) = arrow(tester);
    expect(shift, greaterThan(0));
    expect(opacity, lessThan(1));
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
  });

  testWidgets('**the guard**: with nothing under way it stands still', (
    tester,
  ) async {
    await show(tester, 0);
    expect(arrow(tester), (0.0, 1.0));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  testWidgets("**the guard**: with Windows' animations off it stands still "
      'even while downloading', (tester) async {
    await show(tester, 2, still: true);
    expect(arrow(tester), (0.0, 1.0));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  testWidgets('the motion can be turned off, for the tests of the window', (
    tester,
  ) async {
    await show(tester, 2, motion: false);
    expect(arrow(tester), (0.0, 1.0));
  });
}
