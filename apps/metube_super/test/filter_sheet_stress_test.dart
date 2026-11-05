import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/sort_sheet.dart';
import 'package:metube_super/features/playlists/playlists_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Stress: the sort and filter sheet with everything at once** (owner's
/// request 2026-11-02, "the sheet is too long"): every platform, a hundred
/// folders and a thousand tags (more than can be made, as a backup or a
/// sync may bring), and the sheet still fits a phone's screen.
void main() {
  testWidgets('**the guard**: a thousand tags and a hundred folders keep '
      'the sheet within the screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(384, 823);
    addTearDown(tester.view.reset);
    final items = [
      for (var i = 0; i < 100; i++)
        LibraryItem(
          canonicalUrl: 'https://x/$i',
          title: 'Clip $i',
          serverFilename: 'Folder $i/clip.mp4',
          onServer: true,
          timestamp: DateTime(2026, 11, 2),
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(const SuperSettings()),
          libraryItemsProvider.overrideWith((ref) async => items),
          platformCountsProvider.overrideWithValue([
            for (final p in MediaPlatform.values) MapEntry(p, 12),
          ]),
          tagCountsProvider.overrideWith(
            (ref) async => {for (var i = 0; i < 1000; i++) 'tag $i': 1},
          ),
        ],
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showSortSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Platforms, folders and tags each on one line, however many.
    final rows = find.byType(MTChipRow);
    expect(rows, findsNWidgets(3));
    for (final row in tester.widgetList(rows)) {
      expect(tester.getSize(find.byWidget(row)).height, lessThan(80));
    }
    // A thousand tags arrive, fifty are built until "more" is asked for.
    expect(find.textContaining('# tag '), findsNWidgets(MTConstants.maxTags));
    expect(find.text('More · ${1000 - MTConstants.maxTags}'), findsOneWidget);
  });
}
