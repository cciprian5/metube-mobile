import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **The window matrix**: the desktop twin of the phones' device matrix.
///
/// A window can be any size between the smallest one Ember allows and a
/// maximized 2560-wide screen, and Windows lets the text grow on its own
/// for eyesight. What breaks there is rarely the logic but **the layout**:
/// a label that no longer fits pushes its neighbours out of the frame. In a
/// release build that is not the yellow and black stripe but text cut off
/// without a word, so it is caught here from Flutter's own engine, in both
/// reading directions.
class EmberWindowSize {
  const EmberWindowSize(this.name, this.size);

  final String name;
  final Size size;

  /// Sizes in logical pixels, which is what a window reports at any
  /// Windows display scale.
  static const List<EmberWindowSize> all = [
    // The smallest window Ember allows; the side panel becomes a layer.
    EmberWindowSize('smallest 960x600', Size(960, 600)),
    // The first width with the panel beside the content, sidebar narrow.
    EmberWindowSize('panel beside 1100x700', Size(1100, 700)),
    // The first width with all three columns, and the first window size.
    EmberWindowSize('three columns 1280x800', Size(1280, 800)),
    EmberWindowSize('laptop 1440x900', Size(1440, 900)),
    EmberWindowSize('full HD 1920x1080', Size(1920, 1080)),
    EmberWindowSize('large screen 2560x1440', Size(2560, 1440)),
  ];
}

/// Text sizes: normal, a common choice for eyesight, and double.
const List<double> emberTextScales = [1.0, 1.3, 2.0];

/// Both reading directions the app ships in.
const List<Locale> emberLocales = [Locale('en'), Locale('ar')];

/// Builds [build] at every window size, language and text size, runs
/// [then] to bring the screen into the state under test, and fails at the
/// first overflow, naming where it happened.
///
/// [build] is called afresh each time, so nothing carries over from one
/// size to the next; the app reads its language and text size from the
/// window, as it does on Windows.
Future<void> expectNoOverflow(
  WidgetTester tester,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? then,
  List<EmberWindowSize> windows = EmberWindowSize.all,
  List<double> scales = emberTextScales,
}) async {
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  for (final window in windows) {
    for (final locale in emberLocales) {
      for (final scale in scales) {
        final where = '${window.name}, ${locale.languageCode}, text x$scale';
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = window.size;
        tester.platformDispatcher.localesTestValue = [locale];
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(KeyedSubtree(key: UniqueKey(), child: build()));
        await tester.pumpAndSettle();
        _expectNoError(tester, where);
        if (then != null) {
          await then(tester);
          await tester.pumpAndSettle();
          _expectNoError(tester, where);
        }
      }
    }
  }
}

/// Fails with the whole error, which names the widget that overflowed;
/// the short form says only by how many pixels.
void _expectNoError(WidgetTester tester, String where) {
  final error = tester.takeException();
  if (error != null) fail('overflow at $where\n$error');
}
