import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/downloads_library/widgets/library_cards.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'widget_test.dart' show host;

import 'wahaj_finder.dart';

/// **Favourites from the menu, not an empty heart on every card** (owner's
/// decision 2026-11-01).
void main() {
  LocalItem clip({bool favorite = false}) => LocalItem(
    key: 'https://youtu.be/a',
    path: '$liteMediaDir/a.mp4',
    canonicalUrl: 'https://youtu.be/a',
    title: 'Clip',
    sizeBytes: 10,
    modified: DateTime(2026),
    favorite: favorite,
  );

  Future<void> pump(WidgetTester tester, LocalItem item) async {
    await tester.pumpWidget(
      host(
        LibraryItemCard(item: item, onPlay: () {}, onClearHighlight: () {}),
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          initialSettingsProvider.overrideWithValue(const LiteSettings()),
          localMediaProvider.overrideWith((ref) async => [item]),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('**the guard**: a card carries no heart to tap', (tester) async {
    await pump(tester, clip());
    expect(byWahaj(MTIcons.favorite), findsNothing);
    expect(find.byType(MTFavoriteMark), findsNothing);
  });

  testWidgets('a favourite card shows the small mark', (tester) async {
    await pump(tester, clip(favorite: true));
    expect(find.byType(MTFavoriteMark), findsOneWidget);
  });

  testWidgets('**the guard**: the item menu opens on the favourite row', (
    tester,
  ) async {
    await pump(tester, clip());
    await tester.tap(byWahaj(MTIcons.moreVert));
    await tester.pumpAndSettle();
    expect(find.byType(MTFavoriteTile), findsOneWidget);
  });

  testWidgets('**the guard**: the delete confirmation shows the clip itself', (
    tester,
  ) async {
    await pump(tester, clip());
    await tester.tap(byWahaj(MTIcons.moreVert));
    await tester.pumpAndSettle();
    final delete = find.text('حذف الفيديو');
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
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
  });
}
