import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/folders/folder_tree.dart';
import 'package:metube_desktop/features/library/library_state.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

LibraryItem _in(String id, String? folder) => LibraryItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: 'Clip $id',
  serverFilename: folder == null ? 'Clip $id.mp4' : '$folder/Clip $id.mp4',
  onServer: true,
  timestamp: DateTime(2026, 10, 20),
);

final _library = [
  _in('a', 'Ai'),
  _in('b', 'Ai/Lessons'),
  _in('c', 'Ai/Lessons'),
  _in('d', 'Ai/Talks'),
  _in('e', 'Games'),
  _in('f', null),
];

void main() {
  test('the tree unfolds along the chosen folder only', () {
    List<(String, int, int)> flat(String? open) => [
      for (final f in sidebarFolders(_library, open))
        (f.path, f.count, f.depth),
    ];
    expect(flat(null), [('Ai', 4, 0), ('Games', 1, 0)]);
    expect(flat('Ai/Lessons'), [
      ('Ai', 4, 0),
      ('Ai/Lessons', 2, 1),
      ('Ai/Talks', 1, 1),
      ('Games', 1, 0),
    ]);
    expect(parentFolder('Ai/Lessons'), 'Ai');
    expect(parentFolder('Ai'), isNull);
  });

  Future<ShellHarness> open(
    WidgetTester tester, {
    List<ChannelSubscription> subs = const [],
    String? at,
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: _library,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    h.api.subscriptions = subs;
    h.api.folders = const ServerFolders(video: ['Ai', 'Games']);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    if (at != null) {
      GoRouter.of(tester.element(find.byType(EmberSidebar))).go(at);
      await tester.pumpAndSettle();
    }
    return h;
  }

  Finder inSidebar(String text) => find.descendant(
    of: find.byType(EmberSidebar),
    matching: find.textContaining(text),
  );

  testWidgets('a folder in the sidebar filters the library; again goes up', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(inSidebar('Ai'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmberSidebar)),
    );
    expect(container.read(libraryViewProvider).folder, 'Ai');
    expect(find.text('Clip e'), findsNothing);
    expect(find.text('Clip b'), findsOneWidget);
    // Unfolded, with the folders inside.
    expect(inSidebar('Lessons'), findsOneWidget);
    await tester.tap(inSidebar('Lessons'));
    await tester.pumpAndSettle();
    expect(container.read(libraryViewProvider).folder, 'Ai/Lessons');
    await tester.tap(inSidebar('Lessons'));
    await tester.pumpAndSettle();
    expect(container.read(libraryViewProvider).folder, 'Ai');
    // The chip above the clips takes it off.
    await tester.tap(
      find
          .descendant(
            of: find.byType(Wrap),
            matching: find.textContaining('Ai'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(container.read(libraryViewProvider).folder, isNull);
  });

  testWidgets(
    '**the guard**: following into its own folder names it after the channel',
    (tester) async {
      final h = await open(tester, at: EmberRoutes.channels);
      await tester.tap(find.text('Follow a channel').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'https://x.y/@z');
      await tester.tap(find.byType(MTSwitch));
      await tester.pumpAndSettle();
      expect(find.text('Named after the channel'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
      await tester.pumpAndSettle();
      expect(h.api.channelCalls, [
        'subscribe https://x.y/@z best 60 - compat=false folder=-',
        'update new name=- enabled=- every=- filter=- clear=false '
            'folder=Field Notes - Videos',
      ]);
    },
  );

  testWidgets('a folder picked when following goes with it', (tester) async {
    final h = await open(tester, at: EmberRoutes.channels);
    await tester.tap(find.text('Follow a channel').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'https://x.y/@z');
    await tester.tap(find.byType(MTSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Named after the channel'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Games').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
    await tester.pumpAndSettle();
    expect(h.api.channelCalls, [
      'subscribe https://x.y/@z best 60 - compat=false folder=Games',
    ]);
  });

  testWidgets('an edit sends the folder only when it changed', (tester) async {
    final sub = ChannelSubscription(
      id: 's1',
      name: 'Eric Tech - Videos',
      url: 'https://www.youtube.com/@eric/videos',
      enabled: true,
      checkIntervalMinutes: 60,
      folder: 'Tech Ai 1',
    );
    final h = await open(tester, subs: [sub], at: EmberRoutes.channel('s1'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save settings'));
    await tester.pumpAndSettle();
    expect(h.api.channelCalls.last, endsWith('folder=-'));
    // Off: new clips go back to the top.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MTSwitch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save settings'));
    await tester.pumpAndSettle();
    expect(h.api.channelCalls.last, endsWith('folder='));
  });
}
