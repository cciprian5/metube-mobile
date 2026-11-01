import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/library_chips.dart';
import 'package:metube_super/features/library/widgets/sort_sheet.dart';
import 'package:metube_super/features/playlists/playlists_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_media/library.dart';

import 'device_matrix.dart';

/// **One chip row above the list** (mobile plan 2026-10-31): the tags left
/// their second row for the sort and filter sheet, and a chosen tag shows
/// in the first row with its way out.
void main() {
  late ProviderContainer container;

  Widget app(Widget home) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(const SuperSettings()),
      libraryItemsProvider.overrideWith((ref) async => const []),
      platformCountsProvider.overrideWithValue(const []),
      tagCountsProvider.overrideWith((ref) async => {'Travel': 4, 'Tech': 2}),
    ],
    child: MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return Column(
              children: [
                TextButton(
                  onPressed: () => showSortSheet(context, ref),
                  child: const Text('open'),
                ),
                home,
              ],
            );
          },
        ),
      ),
    ),
  );

  LibraryViewOptions options() => container.read(libraryViewProvider);

  testWidgets('**the guard**: the tags are no longer a row of their own', (
    tester,
  ) async {
    await tester.pumpWidget(app(const LibraryFilterChips()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Travel'), findsNothing);
  });

  testWidgets('**the guard**: the tags are in the sheet, and a tap there '
      'still cycles in, out, gone', (tester) async {
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sort and filter'), findsOneWidget);

    final travel = find.textContaining('Travel');
    await tester.ensureVisible(travel);
    await tester.tap(travel);
    await tester.pump();
    expect(options().tags, {'Travel'});
    await tester.tap(travel);
    await tester.pump();
    expect(options().excludedTags, {'Travel'});
    await tester.tap(travel);
    await tester.pump();
    expect(options().activeFilters, 0);
  });

  testWidgets('**the guard**: a chosen tag shows in the first row, and its '
      '✕ lets it go rather than turning it into an exclusion', (tester) async {
    await tester.pumpWidget(app(const LibraryFilterChips()));
    await tester.pumpAndSettle();
    container.read(libraryViewProvider.notifier).cycleTag('Travel');
    await tester.pumpAndSettle();

    expect(find.textContaining('Travel'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(options().tags, isEmpty);
    expect(options().excludedTags, isEmpty);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('an excluded tag shows struck through', (tester) async {
    await tester.pumpWidget(app(const LibraryFilterChips()));
    await tester.pumpAndSettle();
    final controller = container.read(libraryViewProvider.notifier)
      ..cycleTag('Tech')
      ..cycleTag('Tech');
    expect(controller.state.excludedTags, {'Tech'});
    await tester.pumpAndSettle();

    final chip = tester.widget<InputChip>(find.byType(InputChip));
    expect(chip.labelStyle?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('**the guard**: the chosen favourites chip is ink, like the '
      'rest, and its label carries no glyph', (tester) async {
    await tester.pumpWidget(app(const LibraryFilterChips()));
    await tester.pumpAndSettle();
    container
        .read(libraryViewProvider.notifier)
        .setScope(LibraryScope.favorites);
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Favorites'),
    );
    expect(chip.selected, isTrue);
    expect(chip.selectedColor, isNull);
    expect(find.textContaining('♥'), findsNothing);
    expect(find.textContaining('⚡'), findsNothing);
  });

  group('the dot on the filter button', () {
    Widget button() => Consumer(
      builder: (context, ref, _) => MTFilterButton(
        tooltip: 'Sort and filter',
        active: ref.watch(sheetFiltersOnProvider),
        onPressed: () {},
      ),
    );

    bool dot(WidgetTester tester) =>
        tester.widget<Badge>(find.byType(Badge)).isLabelVisible;

    testWidgets('is off with nothing chosen, and with only a type chosen', (
      tester,
    ) async {
      await tester.pumpWidget(app(button()));
      expect(dot(tester), isFalse);
      container
          .read(libraryViewProvider.notifier)
          .setType(MediaTypeFilter.audio);
      await tester.pump();
      expect(dot(tester), isFalse);
    });

    testWidgets('**the guard**: is on for a tag, a folder or a platform', (
      tester,
    ) async {
      await tester.pumpWidget(app(button()));
      final controller = container.read(libraryViewProvider.notifier);

      controller.cycleTag('Tech');
      await tester.pump();
      expect(dot(tester), isTrue);
      controller
        ..clearTags()
        ..setFolder('Ai');
      await tester.pump();
      expect(dot(tester), isTrue);
      controller
        ..setFolder(null)
        ..setPlatform(MediaPlatform.youtube);
      await tester.pump();
      expect(dot(tester), isTrue);
    });
  });

  testWidgets('the sheet with its tags holds on every device', (tester) async {
    await expectNoOverflow(tester, () => const _Opened());
  });
}

/// The sheet, opened once and measured at every size by the device matrix.
class _Opened extends StatelessWidget {
  const _Opened();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      libraryItemsProvider.overrideWith((ref) async => const []),
      platformCountsProvider.overrideWithValue(const []),
      tagCountsProvider.overrideWith(
        (ref) async => {for (var i = 0; i < 24; i++) 'Tag number $i': i},
      ),
    ],
    child: MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: const _OpensSheet(),
    ),
  );
}

class _OpensSheet extends ConsumerStatefulWidget {
  const _OpensSheet();

  @override
  ConsumerState<_OpensSheet> createState() => _OpensSheetState();
}

class _OpensSheetState extends ConsumerState<_OpensSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showSortSheet(context, ref),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
