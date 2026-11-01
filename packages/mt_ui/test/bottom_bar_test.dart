import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Guard: the bar's pill travels, and the sections fade into each
/// other.** Material's bar grew a new pill under each destination and the
/// shell cut from one section to the next in a single frame; the plan has
/// one pill sliding in 240 and the sections crossing in 160 each way.
void main() {
  const items = [
    MTNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'أ'),
    MTNavItem(icon: Icons.list_outlined, selectedIcon: Icons.list, label: 'ب'),
    MTNavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'ج',
    ),
  ];

  Widget host(int index) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        bottomNavigationBar: MTBottomBar(
          items: items,
          selectedIndex: index,
          onSelected: (_) {},
        ),
        body: MTTabStack(
          index: index,
          children: const [Text('الأول'), Text('الثاني'), Text('الثالث')],
        ),
      ),
    ),
  );

  double pillX(WidgetTester tester) =>
      tester.getCenter(find.byKey(const ValueKey('bar-pill'))).dx;

  testWidgets('the pill slides from one section to the next', (tester) async {
    await tester.pumpWidget(host(0));
    final first = pillX(tester);
    await tester.pumpWidget(host(2));
    await tester.pump(MTMotion.page ~/ 2);
    final midway = pillX(tester);
    await tester.pumpAndSettle();
    final last = pillX(tester);
    expect(midway, greaterThan(first));
    expect(midway, lessThan(last));
  });

  testWidgets('a reader hears which section is chosen', (tester) async {
    await tester.pumpWidget(host(1));
    expect(
      tester.getSemantics(find.text('ب')),
      matchesSemantics(
        label: 'ب',
        hint: 'Tab 2 of 3',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
  });

  testWidgets('the section left fades out before the new one fades in', (
    tester,
  ) async {
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(1));
    await tester.pump(MTMotion.fast ~/ 2);
    double opacityOf(String text) => tester
        .widget<Opacity>(
          find
              .ancestor(of: find.text(text), matching: find.byType(Opacity))
              .first,
        )
        .opacity;
    expect(opacityOf('الأول'), inExclusiveRange(0, 1));
    expect(opacityOf('الثاني'), 0);
    await tester.pumpAndSettle();
    expect(opacityOf('الثاني'), 1);
    expect(find.text('الأول'), findsNothing);
  });
}
