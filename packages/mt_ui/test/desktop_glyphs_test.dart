import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

import 'wahaj_finder.dart';

/// The library's shared cards draw Wahaj icons on a phone and in the
/// Windows app alike, and no Material icon on either.
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

  testWidgets('**the guard**: a phone draws the Wahaj icons too', (
    tester,
  ) async {
    await pump(tester, desktop: false);
    expect(byWahaj(MTIcons.favorite), findsNWidgets(2));
    expect(byWahaj(MTIcons.favoriteOn), findsOneWidget);
    expect(byWahaj(MTIcons.music), findsWidgets);
    expect(find.byType(Icon), findsNothing);
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
