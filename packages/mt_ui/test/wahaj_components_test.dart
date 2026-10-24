import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

double _radius(ShapeBorder? shape) =>
    ((shape! as RoundedRectangleBorder).borderRadius as BorderRadius).topLeft.x;

void main() {
  group('corner scales', () {
    test('**the guard**: the phones keep the corners they always had', () {
      // Literal numbers on purpose: editing the mobile scale fails here
      // before it reaches every card and sheet on the phones.
      final t = mtTheme(MTVariant.superApp, Brightness.light);
      expect(_radius(t.cardTheme.shape), 16);
      expect(_radius(t.chipTheme.shape), 10);
      expect(_radius(t.bottomSheetTheme.shape), 28);
      final field = t.inputDecorationTheme.border! as OutlineInputBorder;
      expect(field.borderRadius.topLeft.x, 13);
    });

    test('the Windows theme takes the smaller scale', () {
      final t = mtDesktopTheme(MTVariant.superApp, Brightness.light);
      expect(_radius(t.cardTheme.shape), 12);
      expect(_radius(t.chipTheme.shape), 8);
      expect(_radius(t.bottomSheetTheme.shape), 20);
      expect(_radius(t.dialogTheme.shape), 18);
      expect(t.textTheme.bodyLarge!.fontSize, 14);
    });
  });

  Widget host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
      MaterialApp(
        theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
        home: Directionality(
          textDirection: dir,
          child: Scaffold(body: Center(child: child)),
        ),
      );

  group('MTSwitch', () {
    testWidgets('a click and the keyboard both toggle it', (tester) async {
      final seen = <bool>[];
      await tester.pumpWidget(
        host(MTSwitch(value: false, onChanged: seen.add, semanticLabel: 'x')),
      );

      await tester.tap(find.byType(MTSwitch));
      expect(seen, [true]);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(seen, [true, true]);
    });

    testWidgets('without a callback it is disabled and ignores taps', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const MTSwitch(value: true, onChanged: null)),
      );
      await tester.tap(find.byType(MTSwitch));
      expect(
        tester.getSemantics(find.byType(MTSwitch)),
        matchesSemantics(
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
        ),
      );
    });
  });

  testWidgets('a badge caps its count', (tester) async {
    await tester.pumpWidget(host(const MTBadge(count: 120)));
    expect(find.text('99+'), findsOneWidget);
    // It hugs its count instead of spreading across whatever holds it.
    await tester.pumpWidget(host(const Wrap(children: [MTBadge(count: 3)])));
    expect(tester.getSize(find.byType(MTBadge)).width, lessThan(40));

    // Arabic does not turn the count into "+99".
    await tester.pumpWidget(
      host(const MTBadge(count: 120), dir: TextDirection.rtl),
    );
    expect(
      tester.widget<Text>(find.text('99+')).textDirection,
      TextDirection.ltr,
    );
  });

  group('showMTConfirm', () {
    Future<bool?> run(WidgetTester tester, String tap) async {
      bool? result;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showMTConfirm(
                context,
                title: 'Delete the clip?',
                message: 'It is removed from the server for good.',
                confirmLabel: 'Delete',
                cancelLabel: 'Cancel',
                destructive: true,
                preview: const MTDialogClip(title: 'Trip to the valley'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // The clip is in the dialog before anything is deleted.
      expect(find.text('Trip to the valley'), findsOneWidget);
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirming resolves true', (tester) async {
      expect(await run(tester, 'Delete'), isTrue);
    });

    testWidgets('cancelling resolves false', (tester) async {
      expect(await run(tester, 'Cancel'), isFalse);
    });

    testWidgets('**the guard**: two long labels at a large text size take '
        'a second line instead of overflowing', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showMTConfirm(
                context,
                title: 'Forget this device',
                message: 'Its transcripts move here first.',
                confirmLabel: 'Forget this device',
                cancelLabel: 'Keep it for now',
                destructive: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Keep it for now'), findsOneWidget);
    });
  });

  group('MTBoxedRow', () {
    Future<MTIcon> chevron(WidgetTester tester, TextDirection dir) async {
      await tester.pumpWidget(
        host(
          MTBoxedGroup(
            title: 'Playback',
            rows: [
              MTBoxedRow(
                icon: MTIcons.playback,
                title: 'Quality',
                value: '1080p',
                onTap: () {},
              ),
            ],
          ),
          dir: dir,
        ),
      );
      return tester.widgetList<MTIcon>(find.byType(MTIcon)).last;
    }

    testWidgets('the chevron points the way the page slides in', (
      tester,
    ) async {
      expect((await chevron(tester, TextDirection.ltr)).icon, MTIcons.forward);
      expect((await chevron(tester, TextDirection.rtl)).icon, MTIcons.back);
      expect(find.text('1080p'), findsOneWidget);
    });
  });
}
