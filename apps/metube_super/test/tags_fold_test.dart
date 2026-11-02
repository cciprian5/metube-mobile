import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/playlists/playlists_providers.dart';
import 'package:metube_super/features/playlists/playlists_screen.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/subscriptions/subscriptions_providers.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Guard: a full set of tags does not take over the playlists tab**
/// (owner's request 2026-11-02, "a sensible limit that does not break the
/// design"): the first twelve, then "more", which shows the rest.
void main() {
  testWidgets('**the guard**: past twelve, the rest wait behind "more"', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'http://nas.local:8081'),
        ),
        libraryItemsProvider.overrideWith((ref) async => const []),
        subscriptionsProvider.overrideWith(
          (ref) async => const SubscriptionsState(subscriptions: []),
        ),
        tagCountsProvider.overrideWith(
          (ref) async => {
            for (var i = 10; i < 10 + MTConstants.maxTags; i++) 'tag $i': 1,
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/playlists',
            routes: [
              GoRoute(
                path: '/playlists',
                builder: (_, _) => const PlaylistsScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('# tag '), findsNWidgets(12));
    final more = find.text('More · ${MTConstants.maxTags - 12}');
    expect(more, findsOneWidget);
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pump();
    expect(find.textContaining('# tag '), findsNWidgets(MTConstants.maxTags));
    expect(find.textContaining('More ·'), findsNothing);
  });
}
