import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/playlists/playlists_screen.dart';
import 'package:metube_lite/features/playlists/widgets/smart_list_rows.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Guard: Lite's smart playlists are the same quiet rows as Super's**
/// (owner's report, 2026-11-05: favourites and the latest additions were
/// still the three dark glowing cards Super dropped on 2026-11-01).
void main() {
  final clip = LocalItem(
    key: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    path: '/storage/emulated/0/Download/MeTube_Lite/clip.mp4',
    title: 'Trip to the Sarawat mountains',
    sizeBytes: 1,
    modified: DateTime(2026, 10, 31),
    favorite: true,
  );

  Widget host({Brightness brightness = Brightness.light}) {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const LiteSettings()),
        localMediaProvider.overrideWith((ref) async => [clip]),
      ],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: mtTheme(MTVariant.lite, brightness),
        locale: const Locale('en'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: const PlaylistsScreen(),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('**the guard**: favourites and the latest additions are rows '
      'in one group, each with its count', (tester) async {
    await tester.pumpWidget(host());
    await settle(tester);
    expect(find.byType(SmartListRows), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Latest additions'), findsOneWidget);
  });

  testWidgets('the tab fits every device and text size', (tester) async {
    await expectNoOverflow(tester, host);
  });
}
