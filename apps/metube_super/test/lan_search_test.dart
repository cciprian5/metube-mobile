import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/settings/widgets/lan_search_sheet.dart';
import 'package:metube_super/features/settings/widgets/server_fields.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **"Search my network" in the server settings** (owner's request
/// 2026-11-04), the computer's search brought to the phone: only when
/// tapped, only on the phone's own network, and what it finds is filled in
/// to be tested and saved like an address typed by hand.
void main() {
  final asked = <String>[];

  /// One network, 192.168.1.0/24, with MeTube on .20 and a locked one on
  /// .30; every other address answers nothing.
  LanProbe probe({Completer<void>? gate}) => LanProbe(
    adapters: () async => [
      (name: 'wlan0', addresses: [InternetAddress('192.168.1.5')]),
    ],
    connect: (host, port, _) async {
      await gate?.future;
      return host.address.endsWith('.20') || host.address.endsWith('.30');
    },
    identify: (url, _) async {
      asked.add(url);
      return LanHit(
        url: url,
        status: url.contains('.30')
            ? MTEndpointStatus.unauthorized
            : MTEndpointStatus.ok,
      );
    },
  );

  Widget host({LanProbe? lan}) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(const SuperSettings()),
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${Directory.systemTemp.path}/mtf_lan.log'),
      ),
      lanProbeProvider.overrideWithValue(lan ?? probe()),
    ],
    child: MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: const Scaffold(body: SingleChildScrollView(child: ServerFields())),
    ),
  );

  setUp(asked.clear);

  testWidgets('**the guard**: a server found fills the address, and nothing '
      'is saved until it is tested', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const ValueKey('lan-search')));
    await tester.pumpAndSettle();

    expect(find.text('http://192.168.1.20:8081'), findsOneWidget);
    expect(find.text('Needs a password'), findsWidgets);
    await tester.tap(find.text('http://192.168.1.20:8081'));
    await tester.pumpAndSettle();

    expect(find.byType(LanSearchSheet), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, 'http://192.168.1.20:8081');
  });

  testWidgets('nothing is asked before the button is tapped', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(asked, isEmpty);
  });

  testWidgets('a network with no MeTube says so', (tester) async {
    await tester.pumpWidget(
      host(
        lan: LanProbe(
          adapters: () async => [
            (name: 'wlan0', addresses: [InternetAddress('192.168.1.5')]),
          ],
          connect: (_, _, _) async => false,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('lan-search')));
    await tester.pumpAndSettle();
    expect(
      find.text('No MeTube server answered on these ports.'),
      findsOneWidget,
    );
  });

  test('**the guard**: Wi-Fi, a cable and the hotspot are searched, mobile '
      'data and tunnels never', () {
    for (final name in ['wlan0', 'wlan1', 'swlan0', 'eth0', 'ap0']) {
      expect(isHomeAdapter(name), isTrue, reason: name);
    }
    for (final name in ['rmnet_data0', 'ccmni0', 'v4-rmnet', 'tun0', 'lo']) {
      expect(isHomeAdapter(name), isFalse, reason: name);
    }
  });

  test('the port of the address typed is searched too', () {
    expect(lanPortsFor(''), [8081, 8086]);
    expect(lanPortsFor('http://192.168.1.20:9000'), [8081, 8086, 9000]);
    expect(lanPortsFor('https://metube.example.com'), [8081, 8086]);
  });

  testWidgets('the sheet holds on every device and text size', (tester) async {
    await expectNoOverflow(
      tester,
      () => ProviderScope(
        overrides: [lanProbeProvider.overrideWithValue(probe())],
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: const Scaffold(body: LanSearchSheet(ports: [8081, 8086])),
        ),
      ),
    );
  });
}
