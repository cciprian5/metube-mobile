import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_media/src/screens/video_actions_row.dart';
import 'package:mt_ui/mt_ui.dart';

import '../wahaj_finder.dart';

/// **Guard: the portrait player's actions are one row of pills** (owner's
/// request 2026-11-02, as in mobile-v2-10): the main one outlined in the
/// ink, sharing and the original link under the ⋮, and a row too long for
/// the screen scrolls rather than squeezes.
void main() {
  Widget host(List<MTPlayerAction> actions, {double width = 384}) =>
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: MTVideoActionsRow(actions: actions),
            ),
          ),
        ),
      );

  testWidgets('**the guard**: what is used less waits under the ⋮', (
    tester,
  ) async {
    var shared = 0;
    // The test font is wide: room enough that the ⋮ is in sight.
    await tester.pumpWidget(
      host(width: 780, [
        MTPlayerAction(
          icon: MTIcons.download,
          label: 'Save to device',
          main: true,
          onTap: () {},
        ),
        MTPlayerAction(
          icon: MTIcons.favorite,
          label: 'Favourite',
          onTap: () {},
        ),
        MTPlayerAction(
          icon: MTIcons.share,
          label: 'Share',
          inMenu: true,
          onTap: () => shared++,
        ),
        MTPlayerAction(
          icon: MTIcons.external,
          label: 'Open the original link',
          inMenu: true,
          onTap: () {},
        ),
      ]),
    );
    expect(find.text('Save to device'), findsOneWidget);
    expect(find.text('Favourite'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Open the original link'), findsNothing);

    await tester.tap(byWahaj(MTIcons.moreVert));
    await tester.pumpAndSettle();
    expect(find.text('Open the original link'), findsOneWidget);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(shared, 1);
    expect(find.text('Open the original link'), findsNothing);
  });

  testWidgets('a long row scrolls on a narrow phone, with nothing cut off', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(width: 300, [
        for (final label in [
          'Save to device',
          'Remove from favourites',
          'Transcript',
          'Listen as audio only',
        ])
          MTPlayerAction(icon: MTIcons.transcript, label: label, onTap: () {}),
      ]),
    );
    expect(tester.takeException(), isNull);
    // It runs into the margins on both sides, so the next pill peeks in at
    // the screen's edge rather than the row seeming to end at the margin.
    expect(
      tester.getSize(find.byType(SingleChildScrollView)).width,
      300 + 2 * MTSpace.pagePad,
    );
  });
}
