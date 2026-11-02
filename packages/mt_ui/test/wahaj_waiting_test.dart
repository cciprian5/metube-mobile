import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Guard: the phones wait, refresh, tick and title the Wahaj way** (mobile
/// plan, stage 16/G): the ring rather than Material's spinner, pull to
/// refresh with the ring and no floating disc, a hairline checkbox, a dark
/// tooltip card and a dialog title in the heading face.
void main() {
  Widget app(Widget home) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: home,
  );

  testWidgets('**the guard**: a pull shows the ring, with no disc, and '
      'refreshes', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: MTPullRefresh(
            onRefresh: () async => refreshed++,
            child: ListView(
              children: [for (var i = 0; i < 30; i++) Text('Row $i')],
            ),
          ),
        ),
      ),
    );
    double ringOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(MTSpinner),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(ringOpacity(), 0);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Row 2')));
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    expect(ringOpacity(), 1);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(refreshed, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  testWidgets('over a dark frame the ring takes the given ink', (tester) async {
    await tester.pumpWidget(
      app(const Center(child: MTSpinner(color: MTPalette.serverCardInk))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dialog title is in the heading face, the tooltip a dark '
      'card with corners of 8, the checkbox a hairline', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (c) {
            theme = Theme.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    final p = MTPalette.of(MTVariant.superApp, Brightness.light);
    expect(theme.dialogTheme.titleTextStyle!.fontFamily, contains(MTType.display));
    final card = theme.tooltipTheme.decoration! as BoxDecoration;
    expect(card.color, p.miniBg);
    expect(card.borderRadius, BorderRadius.circular(8));
    final side = theme.checkboxTheme.side! as WidgetStateBorderSide;
    expect(side.resolve({})!.width, 1);
  });
}
