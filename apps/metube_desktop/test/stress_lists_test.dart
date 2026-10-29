// Discovery tests: many saved lists, a huge library and a huge queue. The
// helpers live in the tags file; this one only adds the scenarios.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/features/library/library_page.dart';
import 'package:metube_desktop/router.dart';
import 'package:mt_media/library.dart';

import 'stress_tags_test.dart' hide main;

Map<String, Object?> saved(
  int i, {
  required bool pinned,
  List<String> urls = const [],
}) => {
  'id': 'p$i',
  'name': 'Playlist number $i',
  'pinned': pinned,
  'createdAt': DateTime(2026, 1, 1).add(Duration(hours: i)).toIso8601String(),
  'items': [
    for (final u in urls) {'canonicalUrl': u},
  ],
};

void main() {
  for (final n in [100, 1000]) {
    for (final window in const [Size(1440, 900), Size(960, 600)]) {
      for (final arabic in [false, if (n == 1000) true]) {
        final label =
            '$n lists ${window.width.toInt()}w ${arabic ? 'ar' : 'en'}';
        testWidgets(label, (tester) async {
          final found = <String>[];
          await boot(
            tester,
            label: label,
            found: found,
            window: window,
            arabic: arabic,
            library: [for (var i = 0; i < 30; i++) item(i)],
            // The first 200 are pinned, so the sidebar carries them all.
            lists: [
              for (var i = 0; i < n; i++)
                saved(i, pinned: i < 200, urls: [url(i % 30)]),
            ],
          );
          await go(tester, EmberRoutes.playlists, label, found);
          await go(tester, EmberRoutes.item(url(0)), label, found);
          await pillDialog(tester, l10n(tester).addToPlaylist, label, found);
          expect(found, isEmpty);
        });
      }
    }
  }

  testWidgets('2000 clips: library, fling, palette', (tester) async {
    const label = '2000 clips';
    final found = <String>[];
    await boot(
      tester,
      label: label,
      found: found,
      library: [for (var i = 0; i < 2000; i++) item(i)],
    );
    final scroll = find.descendant(
      of: find.byType(LibraryPage),
      matching: find.byType(CustomScrollView),
    );
    final flung = await timed(() async {
      await tester.fling(scroll.first, const Offset(0, -4000), 6000);
      await tester.pumpAndSettle();
    });
    debugPrint('[stress] $label: fling settled in $flung ms');
    check(tester, '$label fling', found);

    final palette = await timed(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Clip 19');
      await tester.pumpAndSettle();
    });
    debugPrint('[stress] $label: palette open + search settled in $palette ms');
    check(tester, '$label palette', found);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    check(tester, '$label palette closed', found);
    expect(found, isEmpty);
  });

  testWidgets('a list of 1000 clips, and a queue of 1000', (tester) async {
    const label = '1000-item list';
    final found = <String>[];
    final library = [for (var i = 0; i < 1000; i++) item(i)];
    final h = await boot(
      tester,
      label: label,
      found: found,
      library: library,
      lists: [
        saved(0, pinned: false, urls: [for (var i = 0; i < 1000; i++) url(i)]),
      ],
    );
    await go(tester, EmberRoutes.playlist('p0'), label, found);

    final queued = await timed(() async {
      h.player.showPlaying(
        library.map(toPlaylistItem).toList(),
        playing: false,
      );
      await tester.pumpAndSettle();
    });
    debugPrint('[stress] $label: queue of 1000 shown in $queued ms');
    check(tester, '$label queue shown', found);
    await upNext(tester, label, found);
    expect(found, isEmpty);
  });
}
