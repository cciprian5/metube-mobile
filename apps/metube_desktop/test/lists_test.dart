import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/clip/clip_page.dart';
import 'package:metube_desktop/features/clip/clip_stage.dart';
import 'package:metube_desktop/features/library/library_state.dart';
import 'package:metube_desktop/features/lists/lists_page.dart';
import 'package:metube_desktop/features/lists/playlist_line.dart';
import 'package:metube_desktop/features/lists/playlist_page.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

const _a = 'https://youtu.be/aaaaaaaaaaa';
const _b = 'https://youtu.be/bbbbbbbbbbb';
const _c = 'https://youtu.be/ccccccccccc';
const _gone = 'https://youtu.be/ggggggggggg';

LibraryItem _item(String url, String title, {int day = 20, bool fav = false}) =>
    LibraryItem(
      canonicalUrl: url,
      title: title,
      uploader: 'Field Notes',
      onServer: true,
      isAudio: true,
      timestamp: DateTime(2026, 10, day),
      sizeBytes: 100,
      favorite: fav,
      tags: url == _a ? const ['homelab'] : const [],
    );

final _library = [
  _item(_a, 'Amber Skies', day: 23, fav: true),
  _item(_b, 'Blue Hour', day: 22),
  _item(_c, 'Cold Harbour', day: 21),
];

/// A list saved as the phone saves it: [entries] in order, the last one
/// for a clip no longer in the library.
Map<String, Object?> _saved(
  String id,
  String name,
  List<String> urls, {
  bool pinned = false,
}) => {
  'id': id,
  'name': name,
  'pinned': pinned,
  'createdAt': DateTime(2026, 10, 1).toIso8601String(),
  'items': [
    for (final url in urls)
      {'canonicalUrl': url, 'cachedTitle': url == _gone ? 'Gone Clip' : null},
  ],
};

void main() {
  Future<ShellHarness> open(
    WidgetTester tester, {
    List<Map<String, Object?>> lists = const [],
    String at = EmberRoutes.playlists,
    Size window = const Size(1440, 900),
  }) async {
    ShellHarness.useWindow(tester, window);
    final h = ShellHarness(
      library: _library,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await h.store.setString(PlaylistsStore.prefsKey, jsonEncode(lists));
    await h.store.setString(
      'tags_index',
      jsonEncode({
        _a: ['homelab', MTConstants.favoritesSystemTag],
        _b: ['homelab'],
      }),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    if (at != EmberRoutes.library) {
      GoRouter.of(tester.element(find.byType(EmberSidebar))).go(at);
      await tester.pumpAndSettle();
    }
    return h;
  }

  Future<List<SavedPlaylist>> stored(ShellHarness h) =>
      PlaylistsStore(store: h.store, mutex: PrefsMutex()).readAll();

  testWidgets('the lists page shows the smart lists, the saved and the tags', (
    tester,
  ) async {
    await open(
      tester,
      lists: [
        _saved('p1', 'Evening', [_a, _b]),
      ],
    );
    expect(find.byType(ListsPage), findsOneWidget);
    expect(find.text('Latest additions'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.textContaining('2 items'), findsOneWidget);
    // Favourites are a tag underneath, but never offered as one.
    expect(find.text('${mtName('# homelab')}  2'), findsOneWidget);
    expect(find.textContaining(MTConstants.favoritesSystemTag), findsNothing);
  });

  testWidgets('a smart list plays at a click, as on the phone', (tester) async {
    final h = await open(tester);
    await tester.tap(find.text('Favorites').last);
    await tester.pumpAndSettle();
    expect(h.player.played.map((i) => i.canonicalUrl), [_a]);
  });

  testWidgets('a new list is named, saved, and shown', (tester) async {
    final h = await open(tester);
    await tester.tap(find.text('New playlist').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Morning');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect((await stored(h)).map((p) => p.name), ['Morning']);
    expect(find.text('Morning'), findsOneWidget);
  });

  testWidgets('a tag opens the library filtered by it', (tester) async {
    await open(tester);
    await tester.tap(find.text('${mtName('# homelab')}  2'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmberSidebar)),
    );
    expect(container.read(libraryViewProvider).tags, {'homelab'});
    expect(find.byType(ListsPage), findsNothing);
  });

  testWidgets('renaming a tag onto another merges them; deleting asks', (
    tester,
  ) async {
    final h = await open(tester);
    await tester.tap(find.text('Manage tags'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'lab');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    final tags = TagsIndex(store: h.store, mutex: PrefsMutex());
    expect(await tags.urlsWithTag('lab'), unorderedEquals([_a, _b]));

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('The videos themselves'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(await tags.urlsWithTag('lab'), isEmpty);
    // The heart is not a tag the user manages, and stays.
    expect(await tags.tagsOf(_a), [MTConstants.favoritesSystemTag]);
  });

  group('a list page', () {
    final evening = _saved('p1', 'Evening', [_a, _gone, _b, _c]);

    testWidgets('marks a clip that is gone and plays only what can play', (
      tester,
    ) async {
      final h = await open(tester, lists: [evening], at: '/playlists/p1');
      expect(find.byType(PlaylistPage), findsOneWidget);
      expect(find.text('No longer available'), findsOneWidget);
      await tester.tap(find.text('Play all'));
      await tester.pumpAndSettle();
      // The guard: a dead line in the queue is skipped as broken, which
      // makes the click look as though it played something else.
      expect(h.player.played.map((i) => i.canonicalUrl), [_a, _b, _c]);
      expect(h.player.playedList, 'p1');
      expect((await stored(h)).single.lastPlayedAt, isNotNull);
    });

    testWidgets('a click plays from that clip, counted among the playable', (
      tester,
    ) async {
      final h = await open(tester, lists: [evening], at: '/playlists/p1');
      await tester.tap(find.text('Cold Harbour'));
      await tester.pumpAndSettle();
      expect(h.player.playedFrom, 2);
    });

    testWidgets('the gone lines are removed on request', (tester) async {
      final h = await open(tester, lists: [evening], at: '/playlists/p1');
      await tester.tap(find.text('Remove 1 unavailable'));
      await tester.pumpAndSettle();
      expect((await stored(h)).single.items.map((e) => e.canonicalUrl), [
        _a,
        _b,
        _c,
      ]);
    });

    testWidgets('a line dragged by its grip moves', (tester) async {
      final h = await open(
        tester,
        lists: [
          _saved('p1', 'Evening', [_a, _b, _c]),
        ],
        at: '/playlists/p1',
      );
      final grip = find.descendant(
        of: find.widgetWithText(PlaylistLine, 'Amber Skies'),
        matching: find.byType(ReorderableDragStartListener),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(grip),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(kLongPressTimeout);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 15));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect((await stored(h)).single.items.map((e) => e.canonicalUrl), [
        _b,
        _c,
        _a,
      ]);
    });

    testWidgets('a line taken out comes back in its place with undo', (
      tester,
    ) async {
      final h = await open(
        tester,
        lists: [
          _saved('p1', 'Evening', [_a, _b, _c]),
        ],
        at: '/playlists/p1',
      );
      final cross = find.descendant(
        of: find.widgetWithText(PlaylistLine, 'Blue Hour'),
        matching: find.byType(IconButton),
      );
      await tester.tap(cross);
      await tester.pumpAndSettle();
      expect((await stored(h)).single.items.map((e) => e.canonicalUrl), [
        _a,
        _c,
      ]);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect((await stored(h)).single.items.map((e) => e.canonicalUrl), [
        _a,
        _b,
        _c,
      ]);
    });

    testWidgets('pinned, it has its own place in the sidebar', (tester) async {
      await open(
        tester,
        lists: [
          _saved('p1', 'Evening', [_a]),
        ],
        at: '/playlists/p1',
      );
      final sidebar = find.byType(EmberSidebar);
      expect(
        find.descendant(of: sidebar, matching: find.text('Evening')),
        findsNothing,
      );
      await tester.tap(find.text('Pin to top'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: sidebar, matching: find.text('Evening')),
        findsOneWidget,
      );
      expect(
        tester.widget<EmberSidebar>(sidebar).currentList,
        'p1',
        reason: 'the open list is the one marked',
      );
    });

    testWidgets('deleting asks first, then leaves for the lists', (
      tester,
    ) async {
      final h = await open(tester, lists: [evening], at: '/playlists/p1');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(MTConfirmDialog),
          matching: find.textContaining('Evening'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(await stored(h), isEmpty);
      expect(find.byType(ListsPage), findsOneWidget);
    });
  });

  testWidgets('a card right-clicked offers pin, rename and delete', (
    tester,
  ) async {
    final h = await open(
      tester,
      lists: [
        _saved('p1', 'Evening', [_a]),
      ],
    );
    await tester.tapAt(
      tester.getCenter(find.text('Evening')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    await tester.tap(find.text('Pin to top'));
    await tester.pumpAndSettle();
    expect((await stored(h)).single.pinned, isTrue);
  });

  testWidgets('a clip is ticked into a list from its page, and out again', (
    tester,
  ) async {
    final h = await open(
      tester,
      lists: [
        _saved('p1', 'Evening', [_b]),
      ],
      at: EmberRoutes.item(_a),
    );
    expect(find.byType(ClipPage), findsOneWidget);
    await tester.tap(find.text('Add to Playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evening'));
    await tester.pumpAndSettle();
    expect((await stored(h)).single.items.map((e) => e.canonicalUrl), [_b, _a]);
    await tester.tap(find.text('Evening'));
    await tester.pumpAndSettle();
    expect((await stored(h)).single.items.map((e) => e.canonicalUrl), [_b]);
    // A new list starts with the clip in it.
    await tester.enterText(find.byType(TextField), 'Road trip');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final made = (await stored(h)).firstWhere((p) => p.name == 'Road trip');
    expect(made.items.map((e) => e.canonicalUrl), [_a]);
  });

  testWidgets('deleting from the server takes the clip out of the lists', (
    tester,
  ) async {
    final h = await open(
      tester,
      lists: [
        _saved('p1', 'Evening', [_a, _b]),
      ],
      at: EmberRoutes.item(_b),
    );
    await tester.tapAt(
      tester.getCenter(find.byType(ClipStage)),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete From Server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(h.api.deleted, [
      [_b],
    ]);
    // The guard: a dead line left behind is skipped as broken each time
    // the list plays.
    expect((await stored(h)).single.items.map((e) => e.canonicalUrl), [_a]);
  });

  testWidgets('many pinned lists scroll in a short window, settings stay', (
    tester,
  ) async {
    await open(
      tester,
      lists: [
        for (var i = 0; i < 20; i++)
          _saved('p$i', 'List $i', [_a], pinned: true),
      ],
      window: const Size(960, 600),
    );
    expect(tester.takeException(), isNull);
    // Narrow at this width: settings is its icon, named on hover.
    expect(byLabel('Settings'), findsOneWidget);
  });
}
