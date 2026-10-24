import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// What the mouse and the keyboard add on Windows, and the promise that a
/// phone sees none of it.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required bool desktop,
  }) async {
    final app = MaterialApp(
      theme: desktop
          ? mtDesktopTheme(MTVariant.superApp, Brightness.light)
          : mtTheme(MTVariant.superApp, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
    await tester.pumpWidget(desktop ? MTDesktopApp(child: app) : app);
  }

  Widget card() => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 240,
      child: MTMediaGridCard(title: 'Amber Skies', onTap: () {}),
    ),
  );

  Future<TestGesture> hover(WidgetTester tester, Finder target) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pumpAndSettle();
    return mouse;
  }

  double playMark(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byWidgetPredicate(
            (w) => w is MTIcon && w.icon == MTIcons.play,
          ),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  bool lifted(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(MTHoverLift),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final shadow = (box.decoration as BoxDecoration?)?.boxShadow;
    return shadow != null && shadow.isNotEmpty;
  }

  testWidgets('on Windows a card rises under the mouse and offers play', (
    tester,
  ) async {
    await pump(tester, card(), desktop: true);
    expect(playMark(tester), 0);
    expect(lifted(tester), isFalse);

    final mouse = await hover(tester, find.byType(MTMediaGridCard));
    expect(playMark(tester), 1);
    expect(lifted(tester), isTrue);

    await mouse.moveTo(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(playMark(tester), 0);
    expect(lifted(tester), isFalse);
  });

  testWidgets('**the guard**: on a phone, even with a mouse, nothing moves', (
    tester,
  ) async {
    await pump(tester, card(), desktop: false);
    await hover(tester, find.byType(MTMediaGridCard));
    expect(
      find.descendant(
        of: find.byType(MTHoverLift),
        matching: find.byType(AnimatedContainer),
      ),
      findsNothing,
    );
    expect(find.byType(MTIcon), findsNothing);
  });

  Widget buttons() => MTFocusRingLayer(
    child: Column(
      children: [
        TextButton(onPressed: () {}, child: const Text('One')),
        TextButton(onPressed: () {}, child: const Text('Two')),
      ],
    ),
  );

  Finder ring() => find.byKey(MTFocusRingLayer.ringKey);

  testWidgets('the focus ring follows the keyboard and leaves with a click', (
    tester,
  ) async {
    await pump(tester, buttons(), desktop: true);
    expect(ring(), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(ring(), findsOneWidget);
    final first = tester.getRect(ring());
    expect(first.contains(tester.getCenter(find.text('One'))), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(ring()).contains(tester.getCenter(find.text('Two'))),
      isTrue,
    );

    // A click puts focus where it lands but shows no ring: the mouse knows
    // where it is.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.down(tester.getCenter(find.text('One')));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(ring(), findsNothing);
  });

  test('the desktop theme: thin scrollbar, tooltip after 600ms, no focus '
      'fill', () {
    final theme = mtDesktopTheme(MTVariant.superApp, Brightness.light);
    final p = MTPalette.of(MTVariant.superApp, Brightness.light);
    final bar = theme.scrollbarTheme;
    expect(bar.thickness?.resolve({}), MTDensity.desktop.scrollbar);
    expect(bar.thumbColor?.resolve({}), p.line2);
    expect(bar.thumbColor?.resolve({WidgetState.dragged}), p.ink3);
    expect(theme.tooltipTheme.waitDuration, const Duration(milliseconds: 600));
    expect(theme.focusColor, Colors.transparent);
  });

  test('**the guard**: the phone theme keeps its own focus and scrollbar', () {
    final phone = mtTheme(MTVariant.superApp, Brightness.light);
    expect(phone.focusColor, isNot(Colors.transparent));
    expect(phone.scrollbarTheme.thickness, isNull);
  });
}
