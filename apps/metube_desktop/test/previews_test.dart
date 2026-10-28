import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/previews/shell_previews.dart';

import 'support/shell_harness.dart';

// The previewer is opened by hand, so a preview that stopped building
// would go unnoticed; this builds each one as the previewer would, in
// every variant.

void main() {
  for (final (wrap, language) in [(inEnglish, 'en'), (inArabic, 'ar')]) {
    for (final brightness in Brightness.values) {
      testWidgets('every shell preview builds, $language ${brightness.name}', (
        tester,
      ) async {
        ShellHarness.useWindow(tester, const Size(1280, 800));
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        // Still: a playing clip's bars would sway for ever and the
        // pictures would never settle; this checks they build.
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        for (final (i, preview) in shellPreviews.indexed) {
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey(i),
              home: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 1280,
                  height: 640,
                  child: wrap(preview()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'preview $i');
        }
      });
    }
  }
}
