import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/transcripts/clip_chapters.dart';
import 'package:metube_super/features/transcripts/subtitles.dart';
import 'package:metube_super/features/transcripts/transcript_panel_tabs.dart';
import 'package:metube_super/features/transcripts/transcripts_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Guard: a clip's chapters come from its transcript** (mobile plan,
/// stage 16/F), in the language its subtitles show, and none for a short
/// clip or while transcripts are off.
void main() {
  const url = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
  const short = 'https://www.youtube.com/watch?v=shortclip01';

  /// A talk of [minutes], a line every five seconds, with a long pause
  /// before every two and a half minutes.
  Transcript talk(String clip, String language, String word, int minutes) =>
      Transcript(
        canonicalUrl: clip,
        language: language,
        source: 'captions',
        fetchedAt: DateTime.utc(2026, 11, 2),
        segments: [
          for (var at = 0; at < minutes * 60; at += 5)
            TranscriptSegment(
              start: Duration(seconds: at),
              end: Duration(seconds: at + ((at + 5) % 150 == 0 ? 1 : 5)),
              text: '$word $at.',
            ),
        ],
      );

  Future<ProviderContainer> container({bool enabled = true}) async {
    final store = MemoryKeyValueStore();
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(localeCode: 'ar'),
        ),
        transcriptIndexProvider.overrideWith(
          (ref) async => TranscriptIndex()
            ..add(talk(url, 'en', 'Line', 20))
            ..add(talk(url, 'ar', 'سطر', 20))
            ..add(talk(short, 'ar', 'سطر', 3)),
        ),
      ],
    );
    addTearDown(c.dispose);
    if (enabled) await store.setBool(TranscriptsEnabled.prefsKey, true);
    await c.read(transcriptsEnabledProvider.future);
    await c.read(transcriptIndexProvider.future);
    return c;
  }

  test('**the guard**: a long talk has chapters, in the app\'s language '
      'unless another was picked', () async {
    final c = await container();
    final ar = c.read(clipChaptersProvider((url: url, language: null)));
    expect(ar.length, inInclusiveRange(3, 10));
    expect(ar.first.start, Duration.zero);
    expect(ar.first.opening, startsWith('سطر'));
    final en = c.read(clipChaptersProvider((url: url, language: 'en')));
    expect(en.first.opening, startsWith('Line'));
  });

  test('**the guard**: chapters folded away stay folded, clip after clip '
      'and after a restart', () async {
    final store = MemoryKeyValueStore();
    ProviderContainer open() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(const SuperSettings()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    final first = open().read(subtitlePrefsProvider);
    await pumpEventQueue();
    expect(first.chaptersFolded.value, isFalse);
    first.chaptersFolded.value = true;
    await pumpEventQueue();
    final again = open().read(subtitlePrefsProvider);
    await pumpEventQueue();
    expect(again.chaptersFolded.value, isTrue);
  });

  test('a short clip has none, and none while transcripts are off', () async {
    final c = await container();
    expect(c.read(clipChaptersProvider((url: short, language: null))), isEmpty);
    final off = await container(enabled: false);
    expect(off.read(clipChaptersProvider((url: url, language: null))), isEmpty);
  });

  testWidgets('beside a full-screen video the chapters are a second tab, '
      'the one playing lit', (tester) async {
    final store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    final session = MTVideoSession(
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => true,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
    final chapters = <MTChapter>[
      (start: Duration.zero, opening: 'Where your photos live now'),
      (start: const Duration(minutes: 6), opening: 'One disk is not a plan'),
      (start: const Duration(minutes: 12), opening: 'Copy them nightly'),
    ];
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: TranscriptPanelTabs(
            transcript: const Text('the transcript'),
            chapters: chapters,
            session: session,
            onClose: () => closed++,
          ),
        ),
      ),
    );
    expect(find.text('the transcript'), findsOneWidget);
    await tester.tap(find.textContaining('Chapters'));
    await tester.pump();
    expect(find.text('the transcript'), findsNothing);
    expect(find.text('One disk is not a plan'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('chapter-0'))),
      isSemantics(isSelected: true, isButton: true, hasTapAction: true),
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(closed, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(session.dispose);
  });

  testWidgets('the section and the label hold on every device and text '
      'scale', (tester) async {
    final chapters = <MTChapter>[
      for (var i = 0; i < 7; i++)
        (
          start: Duration(minutes: i * 6),
          opening:
              'لذلك ننسخ اللقطات إلى صندوق ثانٍ كل ليلة، والصندوق الثاني $i',
        ),
    ];
    await expectNoOverflow(
      tester,
      () => MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(MTSpace.pagePad),
            children: [
              MTChapterSection(
                chapters: chapters,
                current: 2,
                onSeek: (_) {},
                onShowAll: () {},
              ),
              Row(
                children: [
                  // As the bar over the video sets its time.
                  Builder(
                    builder: (context) => Text(
                      '16:20 / 48:10',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: MTChapterLabel(
                        chapters: chapters,
                        position: const Duration(minutes: 16),
                        onTap: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  });
}
