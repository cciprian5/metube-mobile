import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/playlists/playlists_screen.dart';
import 'package:metube_super/features/playlists/widgets/smart_list_rows.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/subscriptions/channel_page.dart';
import 'package:metube_super/features/subscriptions/subscriptions_providers.dart';
import 'package:metube_super/features/subscriptions/widgets/channel_row.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Guard: the channels in the playlists tab, and a channel's page**
/// (mobile plan, stage 16/D). Followed channels were reachable only from
/// Settings, as cards with a menu; the tab now lists the first three with
/// what the library holds from each, and each opens a page of its own.
void main() {
  ChannelSubscription sub(String id, String name, {String? folder}) =>
      ChannelSubscription(
        id: id,
        name: name,
        url: 'https://www.youtube.com/@$id',
        enabled: true,
        checkIntervalMinutes: 360,
        folder: folder,
      );

  final subs = [
    sub('a', 'Amber Lens', folder: 'Amber Lens'),
    sub('b', 'Kitchen Notebook'),
    sub('c', 'Woodshop'),
    sub('d', 'Lowlands'),
    sub('e', 'Podcast Cup'),
  ];

  final clip = LibraryItem(
    canonicalUrl: 'https://www.youtube.com/watch?v=lens1',
    title: 'Trip to the Sarawat mountains',
    serverFilename: 'Amber Lens/trip.mp4',
    onServer: true,
    timestamp: DateTime(2026, 10, 31),
  );

  Widget host({required List<ChannelSubscription> following}) {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'http://nas.local:8081'),
        ),
        libraryItemsProvider.overrideWith((ref) async => [clip]),
        subscriptionsProvider.overrideWith(
          (ref) async => SubscriptionsState(subscriptions: following),
        ),
      ],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
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
              routes: [
                GoRoute(
                  path: 'channel/:id',
                  builder: (_, state) =>
                      ChannelPage(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the smart playlists are rows, and three channels follow '
      'with the way to all of them', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(following: subs));
    await settle(tester);
    expect(find.byType(SmartListRows), findsOneWidget);
    expect(find.text('Your channels'), findsOneWidget);
    expect(find.byType(ChannelRow), findsNWidgets(3));
    expect(find.textContaining('5 channels'), findsOneWidget);
  });

  testWidgets('a channel opens its page with its setup and its clips here', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(following: subs));
    await settle(tester);
    // Matched by its own folder: this server's history names no uploader.
    expect(find.textContaining('1 in your library'), findsOneWidget);
    await tester.tap(find.text('Amber Lens'));
    await settle(tester);
    expect(find.byType(ChannelPage), findsOneWidget);
    expect(find.text('Every 6 hours'), findsOneWidget);
    expect(find.text('Check now'), findsOneWidget);
    expect(find.text('Trip to the Sarawat mountains'), findsOneWidget);
  });

  testWidgets('a server that follows nothing adds nothing to the tab', (
    tester,
  ) async {
    await tester.pumpWidget(host(following: const []));
    await settle(tester);
    expect(find.text('Your channels'), findsNothing);
    expect(find.byType(ChannelRow), findsNothing);
  });

  testWidgets('the tab and the page hold on every device and text scale', (
    tester,
  ) async {
    await expectNoOverflow(tester, () => host(following: subs));
  });
}
