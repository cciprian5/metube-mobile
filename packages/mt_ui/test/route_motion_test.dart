import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Guard: sheets, dialogs, notices and pages move at the app's pace.**
///
/// They ran at Flutter's defaults (a sheet 250/200, a dialog fading 150
/// both ways, a notice 250, a page 300 with the one beneath standing
/// still). The plan gives each its own: a sheet 320 up and 200 down, a
/// dialog growing from 0.96 in 240 and gone in 160, a notice out in 160,
/// a page in 240 and back in 200 with the page beneath stepping back, and
/// Android's back swipe followed under the finger.
void main() {
  Widget host(Widget home) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    locale: const Locale('ar'),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    home: home,
  );

  /// The smallest scale among the transforms above [finder].
  double scaleAbove(WidgetTester tester, Finder finder) {
    var scale = 1.0;
    for (final t in tester.widgetList<Transform>(
      find.ancestor(of: finder, matching: find.byType(Transform)),
    )) {
      scale *= t.transform.entry(0, 0);
    }
    for (final t in tester.widgetList<ScaleTransition>(
      find.ancestor(of: finder, matching: find.byType(ScaleTransition)),
    )) {
      scale *= t.scale.value;
    }
    return scale;
  }

  testWidgets('a phone sheet rises in 320 and leaves in 200', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final style = mtSheetMotion(captured)!;
    expect(style.duration, MTMotion.medium);
    expect(style.reverseDuration, MTMotion.leave);
    expect(style.curve, MTMotion.entrance);
  });

  testWidgets('the computer keeps its own sheet', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      host(
        MTDesktopApp(
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(mtSheetMotion(captured), isNull);
  });

  testWidgets('a dialog grows from 0.96 and is gone in 160', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMTDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('حوار')),
              ),
              child: const Text('افتح'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final early = scaleAbove(tester, find.text('حوار'));
    expect(early, lessThan(1));
    expect(early, greaterThanOrEqualTo(MTMotion.recede));
    await tester.pumpAndSettle();
    expect(scaleAbove(tester, find.text('حوار')), 1);

    Navigator.of(tester.element(find.text('حوار'))).pop();
    await tester.pump();
    await tester.pump(MTMotion.fast + const Duration(milliseconds: 10));
    expect(find.text('حوار'), findsNothing);
  });

  testWidgets('a notice leaves in 160', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMTSnack(context, 'إشعار'),
              child: const Text('اعرض'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('اعرض'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.text('اعرض')))
        .hideCurrentSnackBar();
    await tester.pump();
    await tester.pump(MTMotion.fast + const Duration(milliseconds: 10));
    expect(find.text('إشعار'), findsNothing);
  });

  Future<void> pushSecond(WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('الثانية')),
                ),
              ),
              child: const Text('الأولى'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('الأولى'));
    await tester.pump();
  }

  testWidgets('the page beneath steps back and the new one is in by 240', (
    tester,
  ) async {
    await pushSecond(tester);
    await tester.pump(const Duration(milliseconds: 120));
    expect(scaleAbove(tester, find.text('الأولى')), lessThan(1));
    await tester.pump(MTMotion.page);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('الثانية'), findsOneWidget);
  });

  testWidgets('a back swipe shrinks the page under the finger', (tester) async {
    await pushSecond(tester);
    await tester.pumpAndSettle();

    Future<void> send(String method, [Object? arguments]) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.backGesture.name,
          SystemChannels.backGesture.codec.encodeMethodCall(
            MethodCall(method, arguments),
          ),
          (_) {},
        );
    Map<String, Object> event(double progress) => {
      'touchOffset': <double>[5, 300],
      'progress': progress,
      'swipeEdge': 0,
    };

    await send('startBackGesture', event(0));
    await send('updateBackGestureProgress', event(0.5));
    await tester.pump();
    final pulled = scaleAbove(tester, find.text('الثانية'));
    expect(
      pulled,
      closeTo(1 - (1 - MTSlidePageTransition.swipeScale) / 2, 0.01),
    );
    // The page behind is in view while the finger is down.
    expect(find.text('الأولى'), findsOneWidget);

    await send('commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('الثانية'), findsNothing);
  });

  test('no screen calls Flutter\'s sheet or dialog directly', () {
    final raw = RegExp(r'\bshow(Dialog|ModalBottomSheet)<');
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.endsWith('mt_route_motion.dart') &&
            raw.hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
