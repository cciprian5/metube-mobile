import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/library_screen.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

/// **An empty list says why it is empty** (audit 2026-10-30): with the
/// offline chip on and nothing kept on the phone, a full library was
/// announced as "Your library is empty".
void main() {
  HistoryResponse history(int count) => HistoryResponse(
    done: [
      for (var i = 0; i < count; i++)
        HistoryItem(
          id: '$i',
          canonicalUrl: 'https://www.youtube.com/watch?v=item$i',
          title: 'Clip $i',
          filename: 'item$i.mp4',
          status: ItemStatus.completed,
          timestamp: DateTime(2026, 10, 30),
        ),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    required int items,
    LibraryScope scope = LibraryScope.all,
  }) async {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'http://nas.local:8081'),
        ),
        historyProvider.overrideWith((ref) async => history(items)),
      ],
    );
    addTearDown(container.dispose);
    container.read(libraryViewProvider.notifier).setScope(scope);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          home: const LibraryScreen(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('**the guard**: the offline filter over a full library says '
      'nothing is kept on this phone', (tester) async {
    await pump(tester, items: 5, scope: LibraryScope.offline);
    expect(find.text('Nothing saved on this phone yet'), findsOneWidget);
    expect(find.text('Your library is empty'), findsNothing);
  });

  testWidgets('**the guard**: another filter that hides everything says so', (
    tester,
  ) async {
    await pump(tester, items: 5, scope: LibraryScope.favorites);
    expect(find.text('Nothing matches these filters'), findsOneWidget);
    expect(find.text('Your library is empty'), findsNothing);
  });

  testWidgets('a library with nothing in it is still empty', (tester) async {
    await pump(tester, items: 0);
    expect(find.text('Your library is empty'), findsOneWidget);
  });
}
