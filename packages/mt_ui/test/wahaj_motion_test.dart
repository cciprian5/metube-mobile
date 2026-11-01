import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  Widget host(
    Widget child, {
    TextDirection dir = TextDirection.ltr,
    bool reduceMotion = false,
  }) => MaterialApp(
    theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: dir,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );

  test('**the guard**: the phones keep their touch effect', () {
    // Warmth replaces the sparkle in the Windows app only.
    expect(
      mtTheme(MTVariant.superApp, Brightness.light).splashFactory,
      InkSparkle.splashFactory,
    );
    expect(
      mtDesktopTheme(MTVariant.superApp, Brightness.light).splashFactory,
      NoSplash.splashFactory,
    );
  });

  group('progress', () {
    double turn(WidgetTester tester) => tester
        .widget<RotationTransition>(
          find.descendant(
            of: find.byType(MTSpinner),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns
        .value;

    testWidgets('the ring turns', (tester) async {
      await tester.pumpWidget(host(const MTSpinner()));
      final before = turn(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(turn(tester), isNot(before));
    });

    testWidgets('it stands still when the system asks for less motion', (
      tester,
    ) async {
      await tester.pumpWidget(host(const MTSpinner(), reduceMotion: true));
      final before = turn(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(turn(tester), before);
    });

    Future<double> emberX(WidgetTester tester, TextDirection dir) async {
      await tester.pumpWidget(
        host(
          const SizedBox(width: 200, child: MTProgressBar(value: 0.25)),
          dir: dir,
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.getRect(find.byType(MTProgressBar));
      final ember = tester.getCenter(find.byKey(const ValueKey('ember')));
      return ember.dx - bar.left;
    }

    testWidgets('the ember leads from the start of the reading direction', (
      tester,
    ) async {
      expect(await emberX(tester, TextDirection.ltr), closeTo(50, 0.5));
      expect(await emberX(tester, TextDirection.rtl), closeTo(150, 0.5));
    });

    testWidgets('the film strip draws in both directions', (tester) async {
      for (final dir in TextDirection.values) {
        await tester.pumpWidget(
          host(const SizedBox(width: 200, child: MTFilmStrip()), dir: dir),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('MTLinkButton', () {
    // The painter is private; its public `drawn` field is read through
    // dynamic, which is enough for a test.
    double underline(WidgetTester tester) =>
        (tester
                        .widget<CustomPaint>(
                          find.byKey(const ValueKey('underline')),
                        )
                        .foregroundPainter!
                    as dynamic)
                .drawn
            as double;

    testWidgets('the line is drawn while pressed, and a tap acts', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(MTLinkButton(label: 'See all', onPressed: () => taps++)),
      );
      expect(underline(tester), 0);

      final press = await tester.startGesture(
        tester.getCenter(find.text('See all')),
      );
      await tester.pumpAndSettle();
      expect(underline(tester), 1);
      await press.up();
      await tester.pumpAndSettle();
      expect(underline(tester), 0);
      expect(taps, 1);
    });

    testWidgets('Enter activates it from the keyboard', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(MTLinkButton(label: 'See all', onPressed: () => taps++)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    });
  });

  group('notices', () {
    testWidgets('the edge bar takes the state colour', (tester) async {
      final p = MTPalette.of(MTVariant.superApp, Brightness.light);
      for (final (kind, colour) in [
        (MTNoticeKind.done, p.ok),
        (MTNoticeKind.failed, p.err),
        (MTNoticeKind.info, p.accent),
      ]) {
        await tester.pumpWidget(host(MTNotice(message: 'm', kind: kind)));
        final bar = tester.widget<Container>(
          find.byKey(const ValueKey('state-bar')),
        );
        expect((bar.decoration! as BoxDecoration).color, colour);
      }
    });

    testWidgets('on the computer, an action does not make the notice '
        'taller', (tester) async {
      // A pointer's size there; a phone keeps a finger's (snackbar_test).
      await tester.pumpWidget(
        host(
          const MTDesktopApp(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MTNotice(message: 'm', key: ValueKey('plain')),
                MTNotice(
                  message: 'm',
                  actionLabel: 'Undo',
                  key: ValueKey('act'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('act'))).height,
        tester.getSize(find.byKey(const ValueKey('plain'))).height,
      );
    });

    testWidgets('the action runs and the time line runs out', (tester) async {
      var undone = false;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showMTNotice(
                context,
                message: 'Download started',
                kind: MTNoticeKind.done,
                actionLabel: 'Undo',
                onAction: () => undone = true,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final left = tester
          .widget<FractionallySizedBox>(find.byKey(const ValueKey('time-left')))
          .widthFactor!;
      expect(left, inExclusiveRange(0.3, 0.7));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, isTrue);
      expect(find.text('Download started'), findsNothing);
    });
  });

  testWidgets('the empty frame says how to begin and offers a link', (
    tester,
  ) async {
    var pasted = false;
    await tester.pumpWidget(
      host(
        MTEmptyFrame(
          title: 'The library is empty',
          message: 'Share a link from any app, or paste it here.',
          actionLabel: 'Paste a link',
          actionIcon: MTIcons.addlink,
          onAction: () => pasted = true,
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    // **The guard**: words and a link, no drawing above them.
    expect(
      find.descendant(
        of: find.byType(MTEmptyFrame),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget, // the link's own underline, and nothing else
    );
    await tester.tap(find.text('Paste a link'));
    expect(pasted, isTrue);
  });
}
