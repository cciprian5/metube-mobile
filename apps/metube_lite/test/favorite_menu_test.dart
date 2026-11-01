import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/downloads_library/widgets/library_cards.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'widget_test.dart' show host;

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
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
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
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(MTFavoriteTile), findsOneWidget);
  });
}
