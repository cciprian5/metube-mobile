// Discovery tests: how the shell behaves with far more tags than anyone
// has, and with absurdly long names. They report (print) timings and keep
// the first exception of each step, then fail with the whole list, so one
// run shows every finding at once.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/library/library_chips.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/pill.dart';
import 'package:metube_desktop/shell/right_panel.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

String url(int i) => 'https://youtu.be/${'$i'.padLeft(11, '0')}';

LibraryItem item(
  int i, {
  List<String> tags = const [],
  String? title,
  String? uploader,
  String? folder,
}) => LibraryItem(
  canonicalUrl: url(i),
  title: title ?? 'Clip $i',
  uploader: uploader ?? 'Field Notes',
  serverFilename: folder == null ? 'Clip $i.mp4' : '$folder/Clip $i.mp4',
  onServer: true,
  isAudio: i.isOdd,
  timestamp: DateTime(2026, 1, 1).add(Duration(minutes: i)),
  sizeBytes: 1000 + i,
  tags: tags,
);

/// Records the pending exception, if any, under [step].
void check(WidgetTester tester, String step, List<String> found) {
  final e = tester.takeException();
  if (e == null) return;
  final s = e.toString().replaceAll('\n', ' ');
  final kind = s.contains('overflowed') ? 'OVERFLOW' : 'EXCEPTION';
  final line = '$kind at $step: ${s.substring(0, math.min(300, s.length))}';
  found.add(line);
  debugPrint('[stress] $line');
}

Future<int> timed(Future<void> Function() run) async {
  final sw = Stopwatch()..start();
  await run();
  return sw.elapsedMilliseconds;
}

Future<ShellHarness> boot(
  WidgetTester tester, {
  required String label,
  required List<String> found,
  required List<LibraryItem> library,
  Map<String, List<String>> tags = const {},
  List<Map<String, Object?>> lists = const [],
  Size window = const Size(1440, 900),
  bool arabic = false,
  ServerFolders? folders,
}) async {
  ShellHarness.useWindow(tester, window);
  if (arabic) ShellHarness.useArabic(tester);
  final h = ShellHarness(
    library: library,
    server: ServerConfig(baseUrl: 'http://nas:8081'),
  );
  if (folders != null) h.api.folders = folders;
  await h.store.setString('tags_index', jsonEncode(tags));
  await h.store.setString(PlaylistsStore.prefsKey, jsonEncode(lists));
  final ms = await timed(() async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
  });
  debugPrint('[stress] $label: library first frame + settle $ms ms');
  check(tester, '$label library', found);
  return h;
}

MTLocalizations l10n(WidgetTester tester) =>
    tester.element(find.byType(EmberSidebar)).mtl;

Future<void> go(
  WidgetTester tester,
  String route,
  String label,
  List<String> found,
) async {
  final ms = await timed(() async {
    GoRouter.of(tester.element(find.byType(EmberSidebar))).go(route);
    await tester.pumpAndSettle();
  });
  debugPrint('[stress] $label: $route settled in $ms ms');
  check(tester, '$label $route', found);
}

/// Opens a dialog from a clip page pill, settles, records, and closes it.
Future<void> pillDialog(
  WidgetTester tester,
  String pill,
  String label,
  List<String> found,
) async {
  final target = find.widgetWithText(EmberPill, pill);
  // The pills sit under the title; a long one pushes them below the fold.
  final visible =
      tester.getRect(target).bottom <= tester.view.physicalSize.height;
  if (!visible) debugPrint('[stress] $label: pill "$pill" was below the fold');
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  final ms = await timed(() async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  });
  debugPrint('[stress] $label: dialog "$pill" settled in $ms ms');
  check(tester, '$label dialog "$pill"', found);
  if (find.byType(AlertDialog).evaluate().isEmpty) {
    found.add('dialog "$pill" did not open at $label');
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  check(tester, '$label dialog "$pill" closed', found);
}

Future<void> upNext(
  WidgetTester tester,
  String label,
  List<String> found,
) async {
  final tab = find.descendant(
    of: find.byType(EmberRightPanel),
    matching: find.text(l10n(tester).upNext),
  );
  if (tab.evaluate().isEmpty) return;
  final ms = await timed(() async {
    await tester.tap(tab);
    await tester.pumpAndSettle();
  });
  debugPrint('[stress] $label: up next settled in $ms ms');
  check(tester, '$label up next', found);
}

/// [count] characters with no space to break at: Arabic, Latin and emoji.
String longText(int count) {
  const seed = 'وهجEmber🔥مكتبةLibrary✨';
  final b = StringBuffer();
  while (b.length < count) {
    b.write(seed);
  }
  return b.toString().substring(0, count);
}

void main() {
  for (final n in [100, 1000]) {
    for (final window in const [Size(1440, 900), Size(960, 600)]) {
      for (final arabic in [false, if (n == 1000) true]) {
        final label =
            '$n tags ${window.width.toInt()}w ${arabic ? 'ar' : 'en'}';
        testWidgets(label, (tester) async {
          final found = <String>[];
          // Tag j belongs to clip j % 300, so 300 clips carry n tags.
          List<String> tagsOf(int i) => [
            for (var j = i; j < n; j += 300) 'tag-$j',
          ];
          await boot(
            tester,
            label: label,
            found: found,
            window: window,
            arabic: arabic,
            library: [for (var i = 0; i < 300; i++) item(i, tags: tagsOf(i))],
            tags: {for (var i = 0; i < 300; i++) url(i): tagsOf(i)},
          );
          // The chip row scrolls with the grid, so a tall one hides it.
          final chips = tester.getSize(find.byType(LibraryChips)).height;
          final cards = find.byType(MTMediaGridCard).evaluate().length;
          debugPrint(
            '[stress] $label: chip row ${chips.round()} px tall of '
            '${window.height.toInt()}; $cards cards laid out',
          );
          await go(tester, EmberRoutes.item(url(0)), label, found);
          await pillDialog(tester, l10n(tester).tags, label, found);
          await go(tester, EmberRoutes.playlists, label, found);
          expect(found, isEmpty);
        });
      }
    }
  }

  for (final window in const [Size(1440, 900), Size(960, 600)]) {
    final label = 'long text ${window.width.toInt()}w';
    testWidgets(label, (tester) async {
      final found = <String>[];
      final tag = longText(300);
      final folder = longText(200);
      final long = item(
        0,
        tags: [tag],
        title: longText(1000),
        uploader: longText(300),
        folder: folder,
      );
      final h = await boot(
        tester,
        label: label,
        found: found,
        window: window,
        library: [long, for (var i = 1; i < 12; i++) item(i)],
        tags: {
          url(0): [tag],
        },
        folders: ServerFolders(video: [folder]),
        lists: [
          {
            'id': 'p-long',
            'name': longText(500),
            'pinned': true,
            'createdAt': DateTime(2026, 10, 1).toIso8601String(),
            'items': [
              {'canonicalUrl': url(0)},
            ],
          },
        ],
      );
      await go(tester, EmberRoutes.item(url(0)), label, found);
      final l = l10n(tester);
      await pillDialog(tester, l.tags, label, found);
      await pillDialog(tester, l.addToPlaylist, label, found);
      await go(tester, EmberRoutes.playlists, label, found);
      await go(tester, EmberRoutes.playlist('p-long'), label, found);
      h.player.showPlaying([toPlaylistItem(long)], playing: false);
      await tester.pumpAndSettle();
      check(tester, '$label player bar', found);
      await upNext(tester, label, found);
      expect(found, isEmpty);
    });
  }
}
