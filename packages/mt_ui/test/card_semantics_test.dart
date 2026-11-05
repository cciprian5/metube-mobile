import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **What a screen reader lands on in a clip card.** The card's name and
/// its "button" sat on one node while its tap and focus sat on another,
/// under it, with the cover's image flag: Narrator read a focused card as
/// an image. Each card form is now one node that is the button, and its
/// heart a button of its own.
void main() {
  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: Scaffold(
      body: Center(child: SizedBox(width: 640, child: child)),
    ),
  );

  // A cover as `Image` gives it: flagged as an image.
  final cover = Semantics(
    image: true,
    child: const ColoredBox(color: Colors.teal),
  );
  void none() {}

  final cards = <String, Widget>{
    'grid card': MTMediaGridCard(
      title: 'Song',
      subtitle: 'Band',
      thumbnail: cover,
      duration: '3:10',
      onTap: none,
      onFavoriteToggle: none,
    ),
    'list card': MTMediaCard(
      title: 'Song',
      subtitle: 'Band',
      thumbnail: cover,
      duration: '3:10',
      onTap: none,
      onFavoriteToggle: none,
    ),
    'compact card': MTMediaCard(
      compact: true,
      title: 'Song',
      subtitle: 'Band',
      thumbnail: cover,
      duration: '3:10',
      onTap: none,
      onFavoriteToggle: none,
    ),
    'table row': MTMediaRow(
      columns: const MTMediaColumns(),
      title: 'Song',
      subtitle: 'Band',
      thumbnail: cover,
      duration: '3:10',
      onTap: none,
      onFavoriteToggle: none,
    ),
  };

  for (final MapEntry(key: name, value: card) in cards.entries) {
    testWidgets('**the guard**: a $name is one button a reader can reach, '
        'named in full, and its heart another', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(card));
      final reachable = <SemanticsData>[];
      void walk(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.hasAction(SemanticsAction.tap)) reachable.add(data);
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(reachable, hasLength(2), reason: '$reachable');
      final (body, heart) = (reachable.first, reachable.last);
      expect(body.flagsCollection.isButton, isTrue);
      expect(body.flagsCollection.isImage, isFalse);
      expect(body.label, 'Song, Band, 3:10');
      expect(heart.flagsCollection.isButton, isTrue);
      expect(heart.tooltip, 'Add to favorites');
      handle.dispose();
    });
  }
}
