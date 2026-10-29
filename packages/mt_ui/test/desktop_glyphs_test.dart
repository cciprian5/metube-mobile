import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// The library's shared cards draw Wahaj icons in the Windows app, which
/// uses no Material icons, and exactly what they drew before on a phone.
void main() {
  Widget cards() => ListView(
    children: [
      SizedBox(
        width: 240,
        child: MTMediaGridCard(title: 'Amber Skies', onFavoriteToggle: () {}),
      ),
      MTMediaCard(title: 'Amber Skies', audio: true, onFavoriteToggle: () {}),
      MTMediaRow(
        columns: const MTMediaColumns(),
        title: 'Amber Skies',
        favorite: true,
        onFavoriteToggle: () {},
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, {required bool desktop}) async {
    final app = MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 900, child: cards())),
    );
    await tester.pumpWidget(desktop ? MTDesktopApp(child: app) : app);
  }

  testWidgets('**the guard**: a phone keeps its Material icons', (
    tester,
  ) async {
    await pump(tester, desktop: false);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsWidgets);
    expect(find.byType(MTIcon), findsNothing);
  });

  testWidgets('the Windows app draws no Material icon on them', (tester) async {
    await pump(tester, desktop: true);
    expect(find.byType(Icon), findsNothing);
    final names = [
      for (final i in tester.widgetList<MTIcon>(find.byType(MTIcon)))
        i.icon.name,
    ];
    expect(names, containsAll(['favorite_on', 'headphones', 'library']));
    // **The guard**: on a grid cover at rest only a favourite shows its
    // heart; the empty heart waits for the pointer.
    final onCover = [
      for (final i in tester.widgetList<MTIcon>(
        find.descendant(
          of: find.byType(MTMediaGridCard),
          matching: find.byType(MTIcon),
        ),
      ))
        i.icon.name,
    ];
    expect(onCover, isNot(contains('favorite')));
  });
}
