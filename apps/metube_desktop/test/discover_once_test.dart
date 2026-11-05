import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/setup_data.dart';
import 'package:metube_desktop/data/update_data.dart';
import 'package:metube_desktop/features/discover/discover_once.dart';
import 'package:mt_core/mt_core.dart';

import 'support/shell_harness.dart';

/// A first install shows "Discover MeTube Ember" once its server is set:
/// it has no "what's new" to link there. Someone who updates is never
/// shown it unasked.
void main() {
  Future<ShellHarness> start(
    WidgetTester tester, {
    bool setupAtStart = false,
    bool whatsNew = false,
    ServerConfig? server,
    bool pending = false,
    bool update = false,
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': ''}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = ShellHarness(
      library: const [],
      overrides: [
        offerSetupAtStartProvider.overrideWithValue(setupAtStart),
        offerWhatsNewProvider.overrideWithValue(whatsNew),
        initialServerSetupProvider.overrideWithValue(server),
        // Updated from 2.6.0 to 2.7.0, when [update].
        installedVersionProvider.overrideWith((ref) async => '2.7.0'),
      ],
    );
    if (pending) await h.store.setBool(discoverPendingKey, true);
    if (update) {
      await h.store.setString(UpdatePrefs.lastSeenVersionKey, '2.6.0');
    }
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  final server = ServerConfig(baseUrl: 'http://nas:8081');
  final discover = find.text('Discover MeTube Ember');

  testWidgets('**the guard**: the first setup closed with "Later" leaves '
      'Discover for the first start with a server', (tester) async {
    final h = await start(tester, setupAtStart: true);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(discover, findsNothing);
    expect(await h.store.getBool(discoverPendingKey), isTrue);
  });

  testWidgets('**the guard**: the start after, with a server, shows '
      'Discover once', (tester) async {
    final h = await start(tester, server: server, pending: true);
    expect(discover, findsWidgets);
    expect(await h.store.getBool(discoverPendingKey), isNull);
  });

  testWidgets('**the guard**: Discover still waiting for a server does not '
      "hold back an update's notes", (tester) async {
    final h = await start(tester, whatsNew: true, pending: true, update: true);
    expect(find.text("What's new in 2.7.0"), findsOneWidget);
    expect(discover, findsNothing);
    expect(await h.store.getBool(discoverPendingKey), isTrue);
  });

  testWidgets('**the guard**: an update shows its notes, never Discover '
      'unasked', (tester) async {
    await start(tester, server: server, whatsNew: true);
    expect(discover, findsNothing);
  });
}
