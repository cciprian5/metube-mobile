import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/panel/queue_view.dart';
import 'package:metube_desktop/shell/panel/transcript_view.dart';
import 'package:metube_desktop/shell/right_panel.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import 'support/shell_harness.dart';

const _url = 'https://youtu.be/aaaaaaaaaaa';

final _homelab = PlaylistItem(
  canonicalUrl: _url,
  title: 'Homelab Hour - Ep. 12',
  uploader: 'Homelab Hour',
  serverFilename: 'Homelab Hour [aaaaaaaaaaa].mp4',
  duration: const Duration(minutes: 3, seconds: 10),
);

final _transcript = Transcript(
  canonicalUrl: _url,
  language: 'en',
  source: 'sidecar',
  fetchedAt: DateTime(2026, 10, 24),
  segments: [
    for (final (s, text) in [
      (0, 'First rule: a snapshot on the same pool is not a backup.'),
      (20, 'If the pool dies, the snapshots go with it.'),
      (40, 'So we replicate the snapshots to a second box every night.'),
    ])
      TranscriptSegment(
        start: Duration(seconds: s),
        end: Duration(seconds: s + 19),
        text: text,
      ),
  ],
);

void main() {
  Future<ShellHarness> open(
    WidgetTester tester, {
    Map<String, Transcript> transcripts = const {},
    List<PlaylistItem>? queue,
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(transcripts: transcripts);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    // Paused: the playing line's bars would never let the test settle.
    h.player.showPlaying(queue ?? [_homelab], playing: false);
    await tester.pumpAndSettle();
    return h;
  }

  Finder inPanel(Finder f) =>
      find.descendant(of: find.byType(EmberRightPanel), matching: f);

  /// The transcript line marked as the one being said.
  String? litLine(WidgetTester tester) {
    for (final element
        in find
            .descendant(
              of: find.byType(EmberRightPanel),
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.selected == true,
              ),
            )
            .evaluate()) {
      final texts = find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byType(Text),
      );
      for (final t in tester.widgetList<Text>(texts)) {
        if ((t.data ?? '').length > 10) return t.data;
      }
    }
    return null;
  }

  testWidgets('the transcript lights the line being said, and follows', (
    tester,
  ) async {
    final h = await open(tester, transcripts: {_url: _transcript});
    h.player.reach(const Duration(seconds: 25));
    await tester.pumpAndSettle();
    expect(litLine(tester), startsWith('If the pool dies'));
    h.player.reach(const Duration(seconds: 41));
    await tester.pumpAndSettle();
    expect(litLine(tester), startsWith('So we replicate'));
  });

  testWidgets('a click on a line plays from there', (tester) async {
    final h = await open(tester, transcripts: {_url: _transcript});
    await tester.tap(inPanel(find.textContaining('If the pool dies')));
    expect(h.player.calls, ['seek']);
  });

  testWidgets('the lines get the panel; the hint takes only its own line', (
    tester,
  ) async {
    await open(tester, transcripts: {_url: _transcript});
    final whole = tester.getSize(find.byType(TranscriptView)).height;
    final lines = tester
        .getSize(
          find.descendant(
            of: find.byType(TranscriptView),
            matching: find.byType(SingleChildScrollView),
          ),
        )
        .height;
    expect(lines, greaterThan(whole * 0.8));
  });

  testWidgets('a clip with no transcript says so', (tester) async {
    await open(tester);
    expect(inPanel(find.text('No transcript for this clip')), findsOneWidget);
  });

  testWidgets('up next lists the queue, the playing clip marked', (
    tester,
  ) async {
    final h = await open(
      tester,
      queue: [_homelab, clip('Amber Skies'), clip('Blue Hour')],
    );
    await tester.tap(inPanel(find.text('Up next')));
    await tester.pumpAndSettle();
    expect(find.byType(QueueView), findsOneWidget);
    expect(inPanel(find.text('Blue Hour')), findsOneWidget);

    await tester.tap(inPanel(find.text('Blue Hour')));
    expect(h.player.calls, ['skipTo']);
  });

  testWidgets('a line dragged by its grip moves in the queue', (tester) async {
    final h = await open(
      tester,
      queue: [_homelab, clip('Amber Skies'), clip('Blue Hour')],
    );
    await tester.tap(inPanel(find.text('Up next')));
    await tester.pumpAndSettle();
    final grips = find.descendant(
      of: find.byType(QueueView),
      matching: find.byType(ReorderableDragStartListener),
    );
    final row = tester.getSize(inPanel(find.text('Blue Hour'))).height;
    expect(row, greaterThan(0));
    // The last line up to the top.
    final from = tester.getCenter(grips.at(2));
    final top = tester.getCenter(grips.at(0));
    final gesture = await tester.startGesture(from);
    // The grip starts a drag at once, with no press-and-hold.
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(
        Offset.lerp(from, top - const Offset(0, 20), step / 10)!,
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.player.calls, ['move 2 0']);
  });

  testWidgets('the details carry the link, one click from the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await open(tester);
    await tester.tap(inPanel(find.text('Details')));
    await tester.pumpAndSettle();
    expect(inPanel(find.text('Homelab Hour')), findsOneWidget);
    expect(inPanel(find.text('YouTube')), findsOneWidget);
    expect(inPanel(find.text('Streaming from the server')), findsOneWidget);

    await tester.tap(inPanel(find.text('Copy link')));
    await tester.pumpAndSettle();
    expect(copied, _url);
    expect(find.text('Link copied'), findsOneWidget);
  });
}
