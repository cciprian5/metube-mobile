import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/downloads_data.dart';
import 'package:metube_desktop/features/add/add_entry.dart';
import 'package:metube_desktop/features/add/batch_dialog.dart';
import 'package:metube_desktop/features/add/link_lines.dart';
import 'package:metube_desktop/features/add/link_preview.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

const _yt = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
const _yt2 = 'https://youtu.be/bbbbbbbbbbb';
const _insta = 'https://www.instagram.com/reel/Cxyz123/';
const _list = 'https://www.youtube.com/playlist?list=PLabcdefghijklmnop';

/// What the clipboard holds; a test reads nothing real from it.
void clipboard(WidgetTester tester, String text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData'
        ? <String, Object?>{'text': text}
        : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  group('reading links from a text', () {
    test('in order, each with its state', () {
      final read = readLinks(
        'Watch $_yt, then $_insta.\n'
        'Again: https://youtu.be/aaaaaaaaaaa\n'
        'Mine already: $_yt2\n'
        'A list: $_list\n'
        'And https://example.org/page',
        ['https://www.youtube.com/watch?v=bbbbbbbbbbb'],
      );
      expect(read.lines.map((l) => (l.url, l.state)), [
        (_yt, LinkState.ready),
        (_insta, LinkState.ready),
        ('https://youtu.be/aaaaaaaaaaa', LinkState.duplicate),
        (_yt2, LinkState.inLibrary),
        (_list, LinkState.playlist),
        ('https://example.org/page', LinkState.unsupported),
      ]);
      expect(read.ready, [_yt, _insta]);
      expect(read.dropped, 0);
    });

    test('at most a hundred; the rest are counted, not sent', () {
      String links(int n) => [
        for (var i = 0; i < n; i++)
          'https://www.youtube.com/watch?v=${'$i'.padLeft(11, 'x')}',
      ].join(' ');
      expect(MTConstants.maxLinksPerAdd, 100);
      final hundred = readLinks(links(100), const []);
      expect(hundred.lines, hasLength(100));
      expect(hundred.dropped, 0);
      final more = readLinks(links(101), const []);
      expect(more.lines, hasLength(100));
      expect(more.dropped, 1);
    });
  });

  group("the preview, asked of the clip's own site", () {
    Future<(LinkPreview?, List<Uri>)> preview(String url) async {
      final asked = <Uri>[];
      final container = ProviderContainer(
        overrides: [
          previewFetchProvider.overrideWithValue((uri) async {
            asked.add(uri);
            return jsonEncode({
              'title': 'Midnight Sun',
              'thumbnail_url': 'https://s2.dmcdn.net/v/x/x720',
            });
          }),
        ],
      );
      addTearDown(container.dispose);
      return (await container.read(linkPreviewProvider(url).future), asked);
    }

    test('Dailymotion, through its own oEmbed', () async {
      final (got, asked) = await preview(
        'https://www.dailymotion.com/video/x7tgad0',
      );
      expect(got?.thumbnail, 'https://s2.dmcdn.net/v/x/x720');
      expect(asked.single.host, 'www.dailymotion.com');
    });

    test('Instagram: nothing asked of anyone', () async {
      final (got, asked) = await preview(_insta);
      expect(got, isNull);
      expect(asked, isEmpty);
    });
  });

  Future<ShellHarness> open(
    WidgetTester tester, {
    List<LibraryItem> library = const [],
    ShellHarness? harness,
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h =
        harness ??
        ShellHarness(
          library: library,
          server: ServerConfig(baseUrl: 'http://nas:8081'),
          overrides: [
            previewFetchProvider.overrideWithValue(
              (uri) async => jsonEncode({
                'title': 'Homelab Hour - Ep. 12',
                'author_name': 'Homelab Hour',
              }),
            ),
          ],
        );
    clipboard(tester, '');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> openDialog(WidgetTester tester, [String text = '']) async {
    await tester.tap(
      find.descendant(
        of: find.byType(EmberSidebar),
        matching: find.text('Add link'),
      ),
    );
    await tester.pumpAndSettle();
    if (text.isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('one YouTube link: its preview, the numbers, then it is sent', (
    tester,
  ) async {
    final h = await open(tester);
    await openDialog(tester, _yt);
    expect(find.text('Homelab Hour - Ep. 12'), findsOneWidget);
    expect(find.text('Up to 1080p'), findsOneWidget);
    await tester.tap(find.text('Up to 720p'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Start download'));
    await tester.pumpAndSettle();
    final sent = h.engine.submitted.single;
    expect(
      (sent.inputUrl, sent.quality, sent.folder),
      (_yt, Quality.q720, null),
    );
    expect(sent.isBatchMember, isFalse);
  });

  // The owner's decision of 2026-11-04: a height is a ceiling on every video
  // site, and the engine falls back to best where the site has none.
  testWidgets('sound alone offers no heights', (tester) async {
    await open(tester);
    await openDialog(tester, 'https://soundcloud.com/artist/track');
    expect(find.text('Up to 1080p'), findsNothing);
  });

  testWidgets('another video site offers the heights, and audio is audio', (
    tester,
  ) async {
    final h = await open(tester);
    await openDialog(tester, _insta);
    expect(find.text('Up to 1080p'), findsOneWidget);
    // The transcript is YouTube's alone.
    expect(find.text('Fetch its transcript first'), findsNothing);
    await tester.tap(find.text('Audio').last);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Start download'));
    await tester.pumpAndSettle();
    expect(h.engine.submitted.single.quality, Quality.audio);
  });

  testWidgets('a folder chosen is sent; the next add starts at the top', (
    tester,
  ) async {
    final h = await open(tester);
    h.api.folders = const ServerFolders(video: ['Ai', 'Ai/Lessons']);
    await openDialog(tester, _yt);
    await tester.tap(find.text('No folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Lessons'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start download'));
    await tester.pumpAndSettle();
    expect(h.engine.submitted.single.folder, 'Ai/Lessons');
    await openDialog(tester);
    expect(find.text('No folder'), findsOneWidget);
  });

  testWidgets('a server without folders says so in the picker', (tester) async {
    final h = await open(tester);
    h.api.folders = const ServerFolders.disabled();
    await openDialog(tester, _yt);
    await tester.tap(find.text('No folder'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CUSTOM_DIRS'), findsOneWidget);
    expect(find.text('New folder…'), findsNothing);
  });

  testWidgets('several links: one line each, sent as one batch', (
    tester,
  ) async {
    final h = await open(
      tester,
      library: [
        LibraryItem(
          canonicalUrl: 'https://www.youtube.com/watch?v=bbbbbbbbbbb',
          title: 'Mine',
          onServer: true,
        ),
      ],
    );
    await openDialog(tester, '$_yt\n$_insta\n$_yt2\n$_yt');
    expect(find.text('4 links'), findsOneWidget);
    expect(find.text('Already in your library'), findsOneWidget);
    expect(find.text('Repeated above'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add 2 links'));
    await tester.pumpAndSettle();
    expect(h.engine.submitted.map((t) => (t.inputUrl, t.isBatchMember)), [
      (_yt, true),
      (_insta, true),
    ]);
    // A failure keeps its line, says why, and offers another try.
    h.engine.fail(h.engine.submitted.last, const NetworkException());
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cannot reach the server'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(MTLinkButton, 'Retry'),
      ),
    );
    await tester.pumpAndSettle();
    expect(h.engine.submitted, hasLength(3));
    expect(h.engine.submitted.last.inputUrl, _insta);
  });

  testWidgets('past a hundred links the dialog says how many were left', (
    tester,
  ) async {
    await open(tester);
    await openDialog(
      tester,
      [
        for (var i = 0; i < 103; i++)
          'https://www.youtube.com/watch?v=${'$i'.padLeft(11, 'x')}',
      ].join('\n'),
    );
    expect(find.textContaining('3 more were left out'), findsOneWidget);
    expect(find.text('Add 100 links'), findsOneWidget);
  });

  testWidgets('a playlist: its clips ticked, one untick, one saved list', (
    tester,
  ) async {
    final h = ShellHarness(
      library: const [],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      overrides: [
        playlistReaderProvider.overrideWithValue(
          (url) async => PlaylistPreview(
            kind: PlaylistKind.youtube,
            title: 'Homelab Season',
            tracks: [
              for (final id in ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc'])
                PlaylistTrack(
                  url: 'https://www.youtube.com/watch?v=$id',
                  title: 'Episode $id',
                  duration: const Duration(minutes: 30),
                ),
            ],
          ),
        ),
      ],
    );
    await open(tester, harness: h);
    await openDialog(tester, _list);
    expect(find.text('A playlist: choose its clips'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Batch download'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 of 3 selected'), findsOneWidget);
    expect(find.textContaining('1:30:00'), findsOneWidget);
    await tester.tap(find.text('Episode bbbbbbbbbbb'));
    await tester.pump();
    await tester.tap(find.text('Download selected'));
    await tester.pumpAndSettle();
    expect(h.engine.submitted.map((t) => t.isBatchMember), [true, true]);
    final saved = await PlaylistsStore(
      store: h.store,
      mutex: PrefsMutex(),
    ).readAll();
    expect(saved.single.name, 'Homelab Season');
  });

  testWidgets('**the guard**: "then download it to this computer" in a '
      'playlist holds for every clip sent', (tester) async {
    final h = ShellHarness(
      library: const [],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      overrides: [
        playlistReaderProvider.overrideWithValue(
          (url) async => PlaylistPreview(
            kind: PlaylistKind.youtube,
            title: 'Homelab Season',
            tracks: [
              for (final id in ['aaaaaaaaaaa', 'bbbbbbbbbbb'])
                PlaylistTrack(
                  url: 'https://www.youtube.com/watch?v=$id',
                  title: 'Episode $id',
                ),
            ],
          ),
        ),
      ],
    );
    await open(tester, harness: h);
    await openDialog(tester, _list);
    await tester.tap(find.widgetWithText(FilledButton, 'Batch download'));
    await tester.pumpAndSettle();
    final pull = find.text(
      'Then download it to this computer',
      skipOffstage: false,
    );
    await tester.ensureVisible(pull);
    await tester.tap(pull);
    await tester.pump();
    await tester.tap(find.text('Download selected'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmberSidebar)),
    );
    final pulls = container.read(pullAfterProvider);
    expect(h.engine.submitted, hasLength(2));
    expect(pulls.keys.toSet(), {for (final t in h.engine.submitted) t.id});
  });

  group('Ctrl+V', () {
    Future<void> pressCtrlV(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('anywhere, a link in the clipboard opens the dialog', (
      tester,
    ) async {
      await open(tester);
      clipboard(tester, 'look: $_yt');
      await pressCtrlV(tester);
      expect(find.text('Add URL'), findsOneWidget);
      expect(find.text('look: $_yt'), findsOneWidget);
    });

    testWidgets('**the guard**: in a text field it only pastes', (
      tester,
    ) async {
      await open(tester);
      await openDialog(tester);
      clipboard(tester, _yt);
      await pressCtrlV(tester);
      // Still the one dialog, its field focused, not a second dialog.
      expect(find.text('Add URL'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('**the guard**: a text field in the window keeps Ctrl+V', (
      tester,
    ) async {
      final opened = <String>[];
      final field = FocusNode();
      addTearDown(field.dispose);
      clipboard(tester, _yt);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddShortcut(
              onLinks: opened.add,
              child: TextField(focusNode: field),
            ),
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();
      await pressCtrlV(tester);
      expect(opened, isEmpty);
      field.unfocus();
      await tester.pump();
      await pressCtrlV(tester);
      expect(opened, [_yt]);
    });

    testWidgets('no link in the clipboard, nothing opens', (tester) async {
      await open(tester);
      clipboard(tester, 'just words');
      await pressCtrlV(tester);
      expect(find.text('Add URL'), findsNothing);
    });
  });

  testWidgets('the transcript first is offered for one YouTube clip', (
    tester,
  ) async {
    final h = await open(tester);
    await openDialog(tester, _yt);
    final box = find.widgetWithText(
      CheckboxListTile,
      'Fetch its transcript first',
    );
    expect(tester.widget<CheckboxListTile>(box).value, isTrue);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(await h.store.getBool('transcripts_enabled'), isFalse);
  });

  testWidgets('**the guard**: in Arabic the site name stands apart from the '
      'link, not glued to its first letter', (tester) async {
    ShellHarness.useArabic(tester);
    ShellHarness.useWindow(tester, const Size(1440, 900));
    clipboard(tester, '');
    final h = ShellHarness(
      library: const [],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(byLabel('إضافة رابط'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, _yt);
    await tester.pumpAndSettle();
    final site = tester.getRect(find.byKey(const ValueKey('addLinkSite')));
    final link = tester.getRect(find.byType(EditableText).first);
    // Right to left, the site name sits on the link's left.
    expect(link.left - site.right, greaterThanOrEqualTo(MTSpace.sm));
  });

  testWidgets('in Arabic, a narrow window and large text, no overflow', (
    tester,
  ) async {
    ShellHarness.useArabic(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    ShellHarness.useWindow(tester, const Size(960, 600));
    clipboard(tester, '');
    final h = ShellHarness(
      library: const [],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(byLabel('إضافة رابط'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '$_yt\n$_insta');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MTSwitch), findsNothing);
  });
}
