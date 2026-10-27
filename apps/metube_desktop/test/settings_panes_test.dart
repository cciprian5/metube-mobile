import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/channels_data.dart';
import 'package:metube_desktop/data/choices_data.dart';
import 'package:metube_desktop/data/transcripts_data.dart';
import 'package:metube_desktop/data/update_data.dart';
import 'package:metube_desktop/features/add/add_options.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import 'support/shell_harness.dart';

/// Lets real file reads finish between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

String _latest(String version) => jsonEncode({
  'tag_name': 'v$version',
  'body': '## Fixed\n- Faster start.',
  'assets': [
    {
      'name': installerNameFor(version),
      'browser_download_url': 'https://x/setup.exe',
      'size': 28000000,
    },
  ],
});

void main() {
  Future<ShellHarness> open(
    WidgetTester tester,
    String to, {
    Size? workArea,
    List<Override> overrides = const [],
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(
      library: const [],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      workArea: workArea,
      overrides: [
        installedVersionProvider.overrideWith((ref) async => '0.1.0'),
        channelsProvider.overrideWith((ref) async => const ChannelsState([])),
        ...overrides,
      ],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(EmberSidebar))).go(to);
    await tester.pumpAndSettle();
    return h;
  }

  group('appearance', () {
    testWidgets('**the guard**: night chosen here turns the app dark and '
        'is kept', (tester) async {
      final h = await open(tester, '/settings/appearance');
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(await h.store.getString('ember_theme'), 'dark');
    });

    testWidgets('a language chosen here replaces Windows\' own', (
      tester,
    ) async {
      final h = await open(tester, '/settings/appearance');
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(find.text('المظهر واللغة'), findsWidgets);
      expect(await h.store.getString('ember_locale'), 'ar');
    });

    testWidgets('a size this screen cannot hold cannot be chosen', (
      tester,
    ) async {
      final h = await open(
        tester,
        '/settings/appearance',
        workArea: const Size(1093, 566),
      );
      await tester.tap(find.text('150%'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(await h.store.getString('ember_ui_zoom'), isNot('1.5'));
      await tester.tap(find.text('80%'));
      await tester.pumpAndSettle();
      expect(await h.store.getString('ember_ui_zoom'), '0.8');
    });
  });

  group('downloads', () {
    testWidgets('the default quality is kept, and an add starts with it', (
      tester,
    ) async {
      final h = await open(tester, '/settings/downloads');
      await tester.tap(find.text('Audio').first);
      await tester.pumpAndSettle();
      expect(await h.store.getString('video_quality'), 'audio');
      final choice = AddChoice.startingWith(Quality.audio);
      expect(choice.audio, isTrue);
      expect(AddChoice.startingWith(Quality.q720).quality, Quality.q720);
    });

    testWidgets('the list says the quality under Downloads', (tester) async {
      await open(
        tester,
        '/settings/server',
        overrides: [
          initialDefaultQualityProvider.overrideWithValue(Quality.q1080),
        ],
      );
      expect(find.text('1080p'), findsOneWidget);
    });
  });

  testWidgets('subscriptions: the notice can be turned off, and Channels '
      'is one click away', (tester) async {
    final h = await open(tester, '/settings/subscriptions');
    expect(find.text('No channels yet'), findsWidgets);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(await h.store.getBool(NotifyArrivalsNotifier.key), isFalse);
    await tester.tap(find.text('Open Channels'));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(EmberSidebar)));
    expect(router.state.uri.path, '/channels');
  });

  testWidgets('transcripts: counted, and all deleted only after asking', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('ember_words_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final store = TranscriptStore(dir);
    await tester.runAsync(
      () => store.write(
        Transcript(
          canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
          language: 'en',
          source: 'sidecar',
          fetchedAt: DateTime(2026, 10, 24),
          segments: const [
            TranscriptSegment(
              start: Duration.zero,
              end: Duration(seconds: 3),
              text: 'said here',
            ),
          ],
        ),
      ),
    );
    await open(
      tester,
      '/settings/transcripts',
      overrides: [transcriptStoreProvider.overrideWithValue(store)],
    );
    await settle(tester);
    expect(find.text('1 clip'), findsWidgets);

    await tester.tap(find.text('Delete all').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete every transcript?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(dir.existsSync(), isTrue);

    await tester.tap(find.text('Delete all').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all').last);
    await settle(tester);
    expect(dir.existsSync(), isFalse);
    expect(find.text('No clips yet'), findsWidgets);
  });

  testWidgets('updates: a version found shows its notes and can be skipped', (
    tester,
  ) async {
    final h = await open(
      tester,
      '/settings/updates',
      overrides: [
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(
            assetMarker: 'ember',
            assetExtension: '.exe',
            fetch: (_) async => _latest('0.2.0'),
          ),
        ),
      ],
    );
    await tester.tap(find.text('Check now'));
    await settle(tester);
    expect(find.text('Version 0.2.0 is available'), findsWidgets);
    expect(find.textContaining('Faster start.'), findsOneWidget);
    expect(find.text('Install and restart'), findsOneWidget);

    await tester.tap(find.text('Skip this version'));
    await settle(tester);
    expect(find.text('Install and restart'), findsNothing);
    expect(await h.store.getString(UpdatePrefs.skippedVersionKey), '0.2.0');
  });
}
