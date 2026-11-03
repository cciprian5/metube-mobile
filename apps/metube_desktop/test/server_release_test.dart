import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/server_release.dart';
import 'package:metube_desktop/features/settings/server_version_line.dart';
import 'package:metube_desktop/shell/server_line.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/fake_api.dart';

void main() {
  const old = ServerVersion(version: '2026.10.09', ytDlp: '2026.08.19');
  const newest = '2026.11.01';

  group('what the server runs', () {
    late FakeApi api;
    var asked = 0;

    ProviderContainer container({required ServerVersion? version}) {
      api = FakeApi(ServerConfig(baseUrl: 'http://nas:8081'))
        ..version = version;
      asked = 0;
      final c = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          metubeLatestProvider.overrideWithValue(() async {
            asked++;
            return newest;
          }),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('**the guard**: a server behind the newest release says so', () async {
      final release = await container(
        version: old,
      ).read(serverReleaseProvider.future);
      expect(release?.isOutdated, isTrue);
      expect(release?.latest, newest);
    });

    test('a server on the newest release does not', () async {
      final release = await container(
        version: const ServerVersion(version: newest),
      ).read(serverReleaseProvider.future);
      expect(release?.isOutdated, isFalse);
    });

    test('**the guard**: a version that cannot be compared is never called '
        'out of date, and GitHub is not asked', () async {
      for (final version in [
        const ServerVersion(version: 'dev'),
        null,
      ]) {
        final release = await container(
          version: version,
        ).read(serverReleaseProvider.future);
        expect(release?.isOutdated, isFalse);
        expect(asked, 0);
      }
    });
  });

  group('in the window', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      required ServerRelease? release,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            serverConfigProvider.overrideWithValue(
              ServerConfig(baseUrl: 'http://nas:8081'),
            ),
            historyProvider.overrideWith((ref) async => null),
            serverReleaseProvider.overrideWith((ref) async => release),
          ],
          child: MaterialApp(
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
            home: Scaffold(body: SizedBox(width: 480, child: child)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('**the guard**: settings name both versions and the update', (
      tester,
    ) async {
      await pump(
        tester,
        const ServerVersionLine(),
        release: const ServerRelease(version: old, latest: newest),
      );
      expect(find.textContaining('MeTube 2026.10.09'), findsOneWidget);
      expect(find.textContaining('2026.08.19'), findsOneWidget);
      expect(find.text('Update available: $newest'), findsOneWidget);
    });

    testWidgets('settings say nothing of an update when none is known', (
      tester,
    ) async {
      await pump(
        tester,
        const ServerVersionLine(),
        release: const ServerRelease(version: old),
      );
      expect(find.textContaining('Update available'), findsNothing);
    });

    testWidgets('**the guard**: the foot of the sidebar marks a server behind '
        'and stays quiet otherwise', (tester) async {
      Finder mark() => find.byKey(const ValueKey('server-outdated'));
      await pump(
        tester,
        const SidebarServerLine(narrow: false),
        release: const ServerRelease(version: old, latest: newest),
      );
      expect(mark(), findsOneWidget);

      await pump(
        tester,
        const SidebarServerLine(narrow: false),
        release: const ServerRelease(version: old),
      );
      expect(mark(), findsNothing);
    });
  });
}
