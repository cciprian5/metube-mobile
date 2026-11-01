import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/library_cards.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Favourites from the menu, not an empty heart on every card** (owner's
/// decision 2026-11-01).
void main() {
  LibraryItem clip({bool favorite = false}) => LibraryItem(
    canonicalUrl: 'https://youtu.be/a',
    title: 'Clip',
    serverFilename: 'a.mp4',
    onServer: true,
    favorite: favorite,
  );

  Future<void> pump(WidgetTester tester, LibraryItem item) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(
            const SuperSettings(activeUrl: 'http://nas.local:8081'),
          ),
          libraryItemsProvider.overrideWith((ref) async => [item]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          home: Scaffold(
            body: LibraryItemCard(item: item, onPlay: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('**the guard**: a card carries no heart to tap', (tester) async {
    await pump(tester, clip());
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byTooltip('Add to favorites'), findsNothing);
  });

  testWidgets('a favourite card shows the small mark', (tester) async {
    await pump(tester, clip(favorite: true));
    expect(find.byType(MTFavoriteMark), findsOneWidget);
  });

  testWidgets('**the guard**: the item menu opens on the favourite row', (
    tester,
  ) async {
    await pump(tester, clip());
    await tester.tap(find.byTooltip('Item options'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(MTFavoriteTile, 'Add to favorites'),
      findsOneWidget,
    );
  });

  testWidgets('**the guard**: the delete confirmation shows the clip itself', (
    tester,
  ) async {
    await pump(tester, clip());
    await tester.tap(find.byTooltip('Item options'));
    await tester.pumpAndSettle();
    final delete = find.text('Delete from server');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.byType(MTConfirmDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MTDialogClip),
        matching: find.textContaining('Clip'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
