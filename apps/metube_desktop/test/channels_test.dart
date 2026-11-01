import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/channels/channel_match.dart';
import 'package:metube_desktop/features/channels/channel_page.dart';
import 'package:metube_desktop/features/channels/channel_row.dart';
import 'package:metube_desktop/features/channels/channels_page.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

/// Rows shaped as the owner's server answers `/subscriptions`: a channel
/// is named after the tab yt-dlp resolved, " - Videos" and all.
ChannelSubscription _sub(
  String id,
  String name, {
  bool enabled = true,
  String? error,
  DateTime? checked,
  int seen = 55,
  String? folder,
}) => ChannelSubscription(
  id: id,
  name: name,
  url: 'https://www.youtube.com/@$id/videos',
  enabled: enabled,
  checkIntervalMinutes: 60,
  quality: 'best',
  seenCount: seen,
  lastChecked: checked,
  error: error,
  folder: folder,
);

LibraryItem _clip(String id, String uploader, {int day = 20}) => LibraryItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: 'Clip $id',
  uploader: uploader,
  onServer: true,
  timestamp: DateTime(2026, 10, day),
  sizeBytes: 100,
  thumbnail: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
);

void main() {
  group('matching the library to the channels', () {
    test('a channel tab and its uploader are one name', () {
      expect(channelKey('Eric Tech - Videos'), channelKey('Eric Tech'));
      expect(channelKey('Uploads from Eric Tech'), 'eric tech');
      expect(channelKey('  Rakan Saud  - Videos'), 'rakan saud');
      expect(
        channelKey('GAMER SNACK | جيمر سناك - Videos'),
        channelKey('gamer snack | جيمر سناك'),
      );
      // Only a tab at the end goes; a name that says "videos" keeps it.
      expect(channelKey('Videos of Cats'), 'videos of cats');
    });

    test('counts, the unwatched, the last arrival and three covers', () async {
      final match = await matchChannels(
        [
          _clip('a', 'Eric Tech', day: 21),
          _clip('b', 'eric tech', day: 23),
          _clip('c', 'Eric Tech', day: 22),
          _clip('d', 'Eric Tech', day: 19),
          _clip('e', 'Lowlands', day: 20),
          _clip('f', 'Lowlands', day: 18),
          _clip('g', 'Harbour', day: 17),
        ],
        {
          's1': (name: 'Eric Tech - Videos', folder: null),
          's2': (name: 'Rakan Saud - Videos', folder: null),
        },
        started: (url) async => url.endsWith('/b'),
      );
      final eric = match.stats['s1']!;
      expect(eric.count, 4);
      expect(eric.unwatched, 3);
      expect(eric.lastArrival, DateTime(2026, 10, 23));
      expect(eric.covers, [
        for (final id in ['b', 'c', 'a'])
          'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      ]);
      // Nothing of the second here: no entry, so no "0 in your library".
      expect(match.stats.containsKey('s2'), isFalse);
      expect(match.unfollowed.map((c) => (c.name, c.count)), [
        ('Lowlands', 2),
        ('Harbour', 1),
      ]);
      expect(match.namesChannels, isTrue);
    });

    test('a channel saving into its own folder owns the clips there', () async {
      LibraryItem inFolder(String id, String folder, {String? uploader}) =>
          LibraryItem(
            canonicalUrl: 'https://youtu.be/$id',
            title: 'Clip $id',
            uploader: uploader,
            serverFilename: '$folder/Clip $id.mp4',
            onServer: true,
            timestamp: DateTime(2026, 10, 20),
          );
      final match = await matchChannels(
        [
          inFolder('a', 'Tech Ai 1'),
          inFolder('b', 'Tech Ai 1/Older'),
          // Named and in the folder: counted once.
          inFolder('c', 'Tech Ai 1', uploader: 'Eric Tech'),
          inFolder('d', 'Games'),
        ],
        {'s1': (name: 'Eric Tech - Videos', folder: 'Tech Ai 1')},
        started: (_) async => false,
      );
      expect(
        match.stats['s1']!.items.map((i) => i.canonicalUrl),
        unorderedEquals([
          for (final id in ['a', 'b', 'c']) 'https://youtu.be/$id',
        ]),
      );
    });

    test(
      "the owner's real history names no channel, so nothing matches",
      () async {
        final raw = File(
          '../../packages/mt_core/test/fixtures/real/history_real_done.json',
        ).readAsStringSync();
        final history = HistoryResponse.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        final items = mergeLibrary(
          history: history,
          offline: const {},
          tags: const {},
          artwork: const {},
          shapes: const {},
        );
        expect(items, isNotEmpty);
        final match = await matchChannels(items, {
          's1': (name: 'Eric Tech - Videos', folder: null),
          's2': (name: 'ServersatHome - Videos', folder: null),
        }, started: (_) async => false);
        expect(match.stats, isEmpty);
        expect(match.unfollowed, isEmpty);
        expect(match.namesChannels, isFalse);
      },
    );
  });

  Future<ShellHarness> open(
    WidgetTester tester, {
    List<ChannelSubscription>? subs = const [],
    List<LibraryItem> library = const [],
    String at = EmberRoutes.channels,
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: library,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    h.api.subscriptions = subs;
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(EmberSidebar))).go(at);
    await tester.pumpAndSettle();
    return h;
  }

  final checked = DateTime.now().subtract(const Duration(hours: 2));

  testWidgets('the attention first, the paused last, each with its state', (
    tester,
  ) async {
    await open(
      tester,
      subs: [
        _sub('z', 'Zed - Videos', enabled: false, checked: checked),
        _sub('a', 'Alpha - Videos', checked: checked),
        _sub('e', 'Echo - Videos', error: 'HTTP Error 404', checked: checked),
      ],
    );
    expect(find.byType(ChannelsPage), findsOneWidget);
    final rows = tester
        .widgetList<ChannelRow>(find.byType(ChannelRow))
        .map((r) => r.sub.id);
    expect(rows, ['e', 'a', 'z']);
    expect(find.text('HTTP Error 404'), findsOneWidget);
    // **The guard**: only the paused one is announced; an active channel
    // carries no mark of its own beside its switch.
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('a channel with clips here says so; one without never says 0', (
    tester,
  ) async {
    await open(
      tester,
      subs: [
        _sub('a', 'Alpha - Videos', checked: checked),
        _sub('b', 'Bravo - Videos', checked: checked, seen: 12),
      ],
      library: [_clip('1', 'Alpha'), _clip('2', 'Alpha')],
    );
    expect(find.textContaining('2 in your library'), findsOneWidget);
    expect(find.textContaining('2 not watched'), findsOneWidget);
    // The guard: Bravo shows the server's facts alone.
    expect(find.textContaining('0 in your library'), findsNothing);
    expect(find.textContaining('12 videos known'), findsOneWidget);
  });

  testWidgets('an older server, and an empty one, each say what they are', (
    tester,
  ) async {
    await open(tester, subs: null);
    expect(
      find.text('This MeTube is older than subscriptions'),
      findsOneWidget,
    );
    expect(find.text('Follow a channel'), findsNothing);
  });

  testWidgets('with none followed, the way to follow is offered', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('No channels followed yet'), findsOneWidget);
    expect(find.text('Follow a channel'), findsWidgets);
  });

  testWidgets('the switch pauses a channel without asking', (tester) async {
    final h = await open(tester, subs: [_sub('a', 'Alpha - Videos')]);
    await tester.tap(find.byType(MTSwitch));
    await tester.pumpAndSettle();
    expect(
      h.api.channelCalls.single,
      startsWith('update a name=- enabled=false'),
    );
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('following sends the link, the interval and best quality', (
    tester,
  ) async {
    final h = await open(tester);
    await tester.tap(find.text('Follow a channel').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://www.youtube.com/@fieldnotes',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
    await tester.pumpAndSettle();
    expect(h.api.channelCalls, [
      'subscribe https://www.youtube.com/@fieldnotes best 60 - compat=false '
          'folder=-',
    ]);
    expect(find.textContaining('Now following'), findsOneWidget);
    expect(find.byType(ChannelRow), findsOneWidget);
  });

  testWidgets('a channel followed twice is named, in the dialog', (
    tester,
  ) async {
    final h = await open(tester);
    h.api.followFailure = const ServerErrorException(
      'This channel is already subscribed',
    );
    await tester.tap(find.text('Follow a channel').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'https://x.y/@z');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
    await tester.pumpAndSettle();
    expect(find.text('This channel is already followed'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets("a channel's page: the server's facts, check, edit, unfollow", (
    tester,
  ) async {
    final h = await open(
      tester,
      subs: [_sub('a', 'Alpha - Videos', checked: checked, folder: 'Tech')],
      at: EmberRoutes.channel('a'),
    );
    expect(find.byType(ChannelPage), findsOneWidget);
    expect(find.text('Every hour'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('Tech'), findsOneWidget);

    await tester.tap(find.text('Check now'));
    await tester.pumpAndSettle();
    expect(h.api.channelCalls.last, 'check a');

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Alpha');
    await tester.tap(find.widgetWithText(FilledButton, 'Save settings'));
    await tester.pumpAndSettle();
    // The folder is left as it is; only what changed is sent.
    expect(
      h.api.channelCalls.last,
      'update a name=Alpha enabled=- every=- filter=- clear=false folder=-',
    );

    await tester.tap(find.text('Unfollow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfollow').last);
    await tester.pumpAndSettle();
    expect(h.api.channelCalls.last, 'delete a');
    expect(find.byType(ChannelsPage), findsOneWidget);
  });

  testWidgets("a server that names no channel says why its page is empty", (
    tester,
  ) async {
    await open(
      tester,
      subs: [_sub('a', 'Alpha - Videos')],
      library: [
        LibraryItem(
          canonicalUrl: 'https://youtu.be/x',
          title: 'No uploader',
          onServer: true,
        ),
      ],
      at: EmberRoutes.channel('a'),
    );
    expect(find.textContaining("doesn't record which channel"), findsOneWidget);
  });

  testWidgets('**the guard**: a channel that saves into its own folder says '
      'nothing of the kind, even before anything arrives there', (
    tester,
  ) async {
    await open(
      tester,
      subs: [_sub('a', 'Alpha - Videos', folder: 'Alpha')],
      library: [
        LibraryItem(
          canonicalUrl: 'https://youtu.be/x',
          title: 'No uploader',
          onServer: true,
        ),
      ],
      at: EmberRoutes.channel('a'),
    );
    expect(find.textContaining("doesn't record which channel"), findsNothing);
  });

  testWidgets('a channel the library has and nobody follows can be followed', (
    tester,
  ) async {
    await open(
      tester,
      subs: [_sub('a', 'Alpha - Videos')],
      library: [_clip('1', 'Lowlands'), _clip('2', 'Lowlands')],
    );
    expect(find.text('Channels in your library'), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Lowlands'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('in Arabic the page reads right to left without overflow', (
    tester,
  ) async {
    ShellHarness.useArabic(tester);
    await open(
      tester,
      subs: [_sub('a', 'عبدو / ABDO - Videos', checked: checked)],
      library: [_clip('1', 'عبدو / ABDO')],
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('في مكتبتك'), findsOneWidget);
  });
}
