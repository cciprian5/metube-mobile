import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// Sorting from the table's header is the Windows app's; the tablet keeps
/// plain titles and its sort sheet.
void main() {
  const columns = MTMediaColumns(size: true, added: true);

  Future<void> pump(WidgetTester tester, MTTableSort? sort) =>
      tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: MTMediaRowHeader(columns: columns, sort: sort),
            ),
          ),
        ),
      );

  testWidgets('**the guard**: with no sorting the titles are plain text', (
    tester,
  ) async {
    await pump(tester, null);
    expect(
      find.descendant(
        of: find.byType(MTMediaRowHeader),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(find.byType(MTIcon), findsNothing);
  });

  testWidgets('a click on a title sorts by it, the arrow marks the column', (
    tester,
  ) async {
    final asked = <MTTableColumn>[];
    await pump(
      tester,
      MTTableSort(
        column: MTTableColumn.added,
        ascending: false,
        onSort: asked.add,
      ),
    );
    await tester.tap(find.text('Title'));
    await tester.tap(find.text('Size'));
    await tester.tap(find.text('Added'));
    expect(asked, [
      MTTableColumn.title,
      MTTableColumn.size,
      MTTableColumn.added,
    ]);
    // One arrow, beside the column the table is sorted by.
    final arrow = find.byType(MTIcon);
    expect(arrow, findsOneWidget);
    expect(
      tester.getCenter(arrow).dx,
      greaterThan(tester.getCenter(find.text('Added')).dx),
    );
  });
}
