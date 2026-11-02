import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

import 'wahaj_finder.dart';

/// **Guard: the components' own motion from the mobile plan.** Each of
/// these jumped, looped without end or vanished in a frame before.
void main() {
  Widget host(Widget child, {bool desktop = false}) {
    final body = Scaffold(body: Center(child: child));
    return MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: desktop ? MTDesktopApp(child: body) : body,
    );
  }

  group('the equaliser', () {
    testWidgets('no bar snaps from tall to short between two frames', (
      tester,
    ) async {
      await tester.pumpWidget(host(const MTEqualizer()));
      List<double> heights() => [
        for (final box in tester.widgetList<Container>(
          find.descendant(
            of: find.byType(MTEqualizer),
            matching: find.byType(Container),
          ),
        ))
          box.constraints!.maxHeight,
      ];
      var last = heights();
      var widest = 0.0;
      for (var frame = 0; frame < 200; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final now = heights();
        for (var i = 0; i < now.length; i++) {
          final step = (now[i] - last[i]).abs();
          if (step > widest) widest = step;
        }
        last = now;
      }
      // A smooth sway moves a bar a point or so a frame; the seam that
      // was there dropped one by more than half its height at once.
      expect(widest, lessThan(2));
    });
  });

  group('the downloads icon', () {
    bool moving(WidgetTester tester) => tester.hasRunningAnimations;

    // The owner's decision (2026-11-01): a phone arrow that rested after
    // three drops read as a stopped download, so it loops as before.
    testWidgets('on a phone it keeps dropping while anything downloads', (
      tester,
    ) async {
      await tester.pumpWidget(host(const MTDownloadsIcon(active: 1)));
      await tester.pump(MTDownloadsIcon.period * 5);
      expect(moving(tester), isTrue);
      await tester.pumpWidget(host(const MTDownloadsIcon(active: 0)));
      // The count's own swap finishes; the arrow stops at once.
      await tester.pump(MTMotion.page + const Duration(milliseconds: 20));
      expect(moving(tester), isFalse);
    });

    testWidgets('the computer keeps its calm loop', (tester) async {
      await tester.pumpWidget(
        host(const MTDownloadsIcon(active: 1), desktop: true),
      );
      await tester.pump(MTDownloadsIcon.period * 5);
      expect(moving(tester), isTrue);
      await tester.pumpWidget(
        host(const MTDownloadsIcon(active: 0), desktop: true),
      );
    });
  });

  testWidgets('a chip arriving widens from nothing', (tester) async {
    Widget row() => const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MTGrowIn(
          key: ValueKey('new'),
          child: SizedBox(key: ValueKey('chip'), width: 80, height: 32),
        ),
      ],
    );
    await tester.pumpWidget(host(row()));
    await tester.pump(MTMotion.medium ~/ 3);
    final midway = tester.getSize(find.byType(MTGrowIn)).width;
    await tester.pumpAndSettle();
    expect(midway, inExclusiveRange(0, 80));
    expect(tester.getSize(find.byType(MTGrowIn)).width, 80);
  });

  testWidgets('a finished card draws its check where the cancel was', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        MTDownloadProgressCard(
          title: 'مقطع',
          statusText: 'اكتمل',
          onCancel: () {},
          done: true,
        ),
      ),
    );
    expect(find.byType(MTDrawnCheck), findsOneWidget);
    expect(byWahaj(MTIcons.close), findsNothing);
  });

  testWidgets('a row folds away after its moment, then says so', (
    tester,
  ) async {
    var gone = false;
    await tester.pumpWidget(
      host(
        MTFoldAway(
          onGone: () => gone = true,
          child: const SizedBox(width: 200, height: 60),
        ),
      ),
    );
    await tester.pump(MTDrawnCheck.draw ~/ 2);
    expect(tester.getSize(find.byType(MTFoldAway)).height, 60);
    await tester.pump(MTDrawnCheck.draw ~/ 2 + MTMotion.medium ~/ 2);
    expect(
      tester.getSize(find.byType(MTFoldAway)).height,
      inExclusiveRange(0, 60),
    );
    await tester.pumpAndSettle();
    expect(gone, isTrue);
  });
}
