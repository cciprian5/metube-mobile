import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

/// The tags and the add-to-playlist dialogs: a name typed in the field is
/// kept by Done and by the button beside it, not only by Enter. Typed and
/// closed with Done, it vanished, which read as "tags are never made".
void main() {
  const url = 'https://youtu.be/aaaaaaaaaaa';
  final item = LibraryItem(
    canonicalUrl: url,
    title: 'Homelab Hour',
    uploader: 'Field Notes',
    onServer: true,
    timestamp: DateTime(2026, 10, 20),
  );

  Future<ShellHarness> openClip(
    WidgetTester tester, {
    List<Map<String, Object>> playlists = const [],
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: [item],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    // Before the first read: lists are read once at start.
    if (playlists.isNotEmpty) {
      await h.store.setString(PlaylistsStore.prefsKey, jsonEncode(playlists));
    }
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await doubleClick(
      tester,
      find
          .descendant(
            of: find.byType(MTMediaGridCard),
            matching: find.text('Homelab Hour'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> openPill(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<List<String>> tagsOf(ShellHarness h) async {
    final raw = await h.store.getString('tags_index') ?? '{}';
    final map = json.decode(raw) as Map<String, dynamic>;
    return [for (final t in map[url] as List? ?? const []) t.toString()];
  }

  Future<List<Map<String, dynamic>>> lists(ShellHarness h) async {
    final raw = await h.store.getString(PlaylistsStore.prefsKey) ?? '[]';
    return [
      for (final l in json.decode(raw) as List) l as Map<String, dynamic>,
    ];
  }

  testWidgets('**the guard**: a tag typed and left in the field is made on '
      'Done', (tester) async {
    final h = await openClip(tester);
    await openPill(tester, 'Tags');
    await tester.enterText(find.byType(TextField).last, 'evening');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(await tagsOf(h), ['evening']);
  });

  testWidgets('**the guard**: the button beside the field makes the tag and '
      'clears the field for the next', (tester) async {
    final h = await openClip(tester);
    await openPill(tester, 'Tags');
    await tester.enterText(find.byType(TextField).last, 'morning');
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    expect(await tagsOf(h), ['morning']);
    expect(find.widgetWithText(CheckboxListTile, 'morning'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      isEmpty,
    );
  });

  testWidgets('**the guard**: a list name typed and left in the field is '
      'made on Done, with the clip in it', (tester) async {
    final h = await openClip(tester);
    await openPill(tester, 'Add to Playlist');
    await tester.enterText(find.byType(TextField).last, 'Weekend');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    final made = await lists(h);
    expect(made.map((l) => l['name']), ['Weekend']);
    expect((made.single['items'] as List).single['canonicalUrl'], url);
  });

  testWidgets('ticking a list puts the clip in it; unticking takes it out', (
    tester,
  ) async {
    final h = await openClip(
      tester,
      playlists: [
        {
          'id': 'p1',
          'name': 'Music',
          'createdAt': DateTime(2026, 10, 1).toIso8601String(),
          'items': <Object>[],
        },
      ],
    );
    await openPill(tester, 'Add to Playlist');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Music'));
    await tester.pumpAndSettle();
    expect(((await lists(h)).single['items'] as List).length, 1);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Music'));
    await tester.pumpAndSettle();
    expect((await lists(h)).single['items'], isEmpty);
  });
}
