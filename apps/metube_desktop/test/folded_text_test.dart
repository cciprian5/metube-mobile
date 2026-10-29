import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/folded_text.dart';
import 'package:mt_ui/mt_ui.dart';

/// Long help under a setting keeps to two lines with "More"; a short one
/// shows no link at all.
void main() {
  Widget host(String text) => MaterialApp(
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
    // In a scrolling page, as every settings pane is.
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: 300, child: FoldedText(text)),
      ),
    ),
  );

  testWidgets('**the guard**: a long help text folds behind More and opens', (
    tester,
  ) async {
    await tester.pumpWidget(host('A sentence that goes on. ' * 20));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byType(Text).first).maxLines, 2);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byType(Text).first).maxLines, isNull);
    expect(find.text('Less'), findsOneWidget);
  });

  testWidgets('a short one shows no link', (tester) async {
    await tester.pumpWidget(host('Short.'));
    await tester.pumpAndSettle();
    expect(find.text('More'), findsNothing);
  });
}
