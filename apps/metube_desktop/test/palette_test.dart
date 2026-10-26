import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/saved_searches.dart';
import 'package:metube_desktop/data/transcripts_data.dart';
import 'package:metube_desktop/features/clip/clip_page.dart';
import 'package:metube_desktop/features/palette/palette_model.dart';
import 'package:metube_desktop/features/palette/palette_rows.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

LibraryItem _clip(String id, String title, {bool audio = false}) => LibraryItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: title,
  uploader: 'Field Notes',
  onServer: true,
  isAudio: audio,
  timestamp: DateTime(2026, 10, 20),
  sizeBytes: 100,
);

final _library = [
  _clip('aaaaaaaaaaa', 'أساسيات الإنشاء في الحديقة'),
  _clip('bbbbbbbbbbb', 'Snapshots are not backups'),
  _clip('ccccccccccc', 'Pool layouts compared'),
];

Transcript _said(String url, List<(int, String)> lines) => Transcript(
  canonicalUrl: url,
  language: 'en',
  source: 'sidecar',
  fetchedAt: DateTime(2026, 10, 24),
  segments: [
    for (final (s, text) in lines)
      TranscriptSegment(
        start: Duration(seconds: s),
        end: Duration(seconds: s + 19),
        text: text,
      ),
  ],
);

TranscriptIndex _index() => TranscriptIndex()
  ..add(
    _said('https://youtu.be/ccccccccccc', [
      (0, 'Mirrors first.'),
      (40, 'Then we replicate every night to a second box.'),
    ]),
  )
  // A clip no longer in the library: its words have nothing to open.
  ..add(_said('https://youtu.be/gone0000000', [(5, 'replicate it all')]));

void main() {
  group('the ranking', () {
    PaletteCommand command(String label) =>
        PaletteCommand(label: label, icon: MTIcons.library, run: () {});

    test('a title is found without the hamza it is written with', () {
      final r = paletteResults(
        query: 'اساسيات',
        items: _library,
        commands: const [],
      );
      expect(r.titles.single.canonicalUrl, 'https://youtu.be/aaaaaaaaaaa');
    });

    test('what was said is found only in clips the library still has', () {
      final r = paletteResults(
        query: 'replicate',
        items: _library,
        commands: const [],
        index: _index(),
      );
      expect(r.said.single.item.canonicalUrl, 'https://youtu.be/ccccccccccc');
      expect(r.said.single.hit.start, const Duration(seconds: 40));
    });

    test('after > only commands, by their names', () {
      final r = paletteResults(
        query: '> lib',
        items: _library,
        commands: [command('Library'), command('Channels')],
      );
      expect(r.titles, isEmpty);
      expect(r.commands.map((c) => c.label), ['Library']);
      expect(r.canSave, isFalse);
    });

    test('a search already saved is not offered again', () {
      final r = paletteResults(
        query: 'pool',
        items: _library,
        commands: const [],
        savedQueries: {'pool'},
      );
      expect(r.canSave, isFalse);
    });
  });

  group('the palette in the window', () {
    Future<ShellHarness> open(WidgetTester tester) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final h = ShellHarness(
        library: _library,
        overrides: [
          transcriptIndexProvider.overrideWith((ref) async => _index()),
        ],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      return h;
    }

    Future<void> ctrlK(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    Finder hint() => find.text(
      'Search titles and what was said, or type > '
      'for commands',
    );

    Finder inRow<T>(String text) =>
        find.descendant(of: find.byType(T), matching: find.text(text));

    ProviderContainer container(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(EmberSidebar)));

    testWidgets('**the guard**: Ctrl+K opens it, the arrows choose, Enter '
        'opens the clip, Esc closes', (tester) async {
      await open(tester);
      await ctrlK(tester);
      expect(hint(), findsOneWidget);
      // Again while it is open: still one.
      await ctrlK(tester);
      expect(hint(), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'o');
      await tester.pump();
      // "o" is too short to search: every command is listed instead.
      await tester.enterText(find.byType(TextField).last, 'pool');
      await tester.pumpAndSettle();
      expect(inRow<TitleRow>('Pool layouts compared'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(hint(), findsNothing);
      expect(
        tester.widget<ClipPage>(find.byType(ClipPage)).canonicalUrl,
        'https://youtu.be/ccccccccccc',
      );

      await ctrlK(tester);
      expect(hint(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(hint(), findsNothing);
    });

    testWidgets('**the guard**: a line that was said plays from its second', (
      tester,
    ) async {
      final h = await open(tester);
      await ctrlK(tester);
      await tester.enterText(find.byType(TextField).last, 'replicate');
      await tester.pumpAndSettle();
      expect(find.text('Said inside clips'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SaidRow),
          matching: find.textContaining('0:40'),
        ),
        findsOneWidget,
      );
      // No title holds the word, so the moment is the first row.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        h.player.played.single.canonicalUrl,
        'https://youtu.be/ccccccccccc',
      );
      expect(h.player.sought, const Duration(seconds: 40));
    });

    testWidgets('the down arrow moves to the next row', (tester) async {
      await open(tester);
      await ctrlK(tester);
      await tester.enterText(find.byType(TextField).last, 'pool');
      await tester.pumpAndSettle();
      // One title, no command by that name, then saving.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // The second row was "Save this search", not the clip.
      expect(find.byType(ClipPage), findsNothing);
      final saved = await container(tester).read(savedSearchesProvider.future);
      expect(saved.single.query, 'pool');
    });

    // The focus stays in the field while the arrows move the highlight,
    // so a screen reader heard nothing of the results.
    testWidgets('**the guard**: a screen reader hears each row the arrows '
        'reach, and finds the rows as buttons with the chosen one selected', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final heard = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message! as Map<Object?, Object?>;
            if (map['type'] == 'announce') {
              heard.add(
                (map['data']! as Map<Object?, Object?>)['message']! as String,
              );
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await open(tester);
      await ctrlK(tester);
      await tester.enterText(find.byType(TextField).last, 'pool');
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(TitleRow)),
        isSemantics(isButton: true, isSelected: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(heard, ['Save this search', 'Pool layouts compared, Field Notes']);
      semantics.dispose();
    });

    // Opened from the search, focus had nowhere to return to: a screen
    // reader said nothing until Tab.
    testWidgets('**the guard**: a clip opened from the search takes the '
        'keyboard into its page', (tester) async {
      await open(tester);
      ShellHarness.useWindow(tester, const Size(1000, 560));
      await ctrlK(tester);
      await tester.enterText(find.byType(TextField).last, 'pool');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(
        focused!.findAncestorWidgetOfExactType<ClipPage>(),
        isNotNull,
        reason: '$focused',
      );
      // And in view, though the window is too short to show it at first.
      final shown = tester.getRect(find.byWidget(focused.widget));
      expect(shown.bottom, lessThanOrEqualTo(560), reason: '$shown');
    });

    testWidgets('**the guard**: a saved search keeps its query, not its '
        'results, and is renamed and deleted from its menu', (tester) async {
      final h = await open(tester);
      await ctrlK(tester);
      await tester.enterText(find.byType(TextField).last, 'snapshots');
      await tester.pumpAndSettle();
      await tester.tap(inRow<CommandRow>('Save this search'));
      await tester.pumpAndSettle();
      expect(
        await h.store.getString(SavedSearches.key),
        contains('"query":"snapshots"'),
      );
      expect(
        await h.store.getString(SavedSearches.key),
        isNot(contains('youtu.be')),
      );
      final entry = find.descendant(
        of: find.byType(EmberSidebar),
        matching: find.text('snapshots'),
      );
      expect(entry, findsOneWidget);

      // Opened again, it searches anew.
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(inRow<TitleRow>('Snapshots are not backups'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(entry, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Backups');
      await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
      await tester.pumpAndSettle();
      final renamed = find.descendant(
        of: find.byType(EmberSidebar),
        matching: find.text('Backups'),
      );
      expect(renamed, findsOneWidget);

      await tester.tap(renamed, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      // The dialog's title and its button both say it; the button is last.
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(renamed, findsNothing);
      expect(await h.store.getString(SavedSearches.key), '[]');
    });
  });
}
