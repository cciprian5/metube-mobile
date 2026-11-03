import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// Saving, restoring and using the Cloudflare Access pair (feature 001,
/// FR-005, FR-010, FR-016).
///
/// The defect these guard against is a pair that is stored but never used,
/// or used but not stored: it works until the app restarts, or it never works
/// at all.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);

  final int status;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      status == 200 ? '{"done":[],"queue":[]}' : 'no',
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const url = 'https://metube.example.com';
  final pair = CloudflareAccess(clientId: 'id.access', clientSecret: 's3cr3t');

  late MemorySecretStore secrets;
  late MemoryKeyValueStore store;
  late ProviderContainer container;

  ProviderContainer make([SuperSettings settings = const SuperSettings()]) {
    secrets = MemorySecretStore();
    store = MemoryKeyValueStore();
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(secrets),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  MeTubeApiClient Function(ServerConfig) via(_Adapter adapter) =>
      (config) => MeTubeApiClient(
        config: config,
        dio: Dio()..httpClientAdapter = adapter,
      );

  test(
    'a good connection tests with the pair, then stores both values',
    () async {
      make();
      final adapter = _Adapter(200);
      await container
          .read(settingsProvider.notifier)
          .saveServer(url: url, access: pair, clientFor: via(adapter));

      // The pair was part of the test, so a wrong one is caught before saving.
      expect(
        adapter.requests.single.headers['CF-Access-Client-Id'],
        'id.access',
      );
      expect(
        adapter.requests.single.headers['CF-Access-Client-Secret'],
        's3cr3t',
      );
      expect(await secrets.read(SecretKeys.cfAccessClientId), 'id.access');
      expect(await secrets.read(SecretKeys.cfAccessClientSecret), 's3cr3t');
      expect(container.read(settingsProvider).cloudflareAccess, pair);
      expect(container.read(settingsProvider).serverConfig?.access, pair);
    },
  );

  test('the active-URL storage is what it was', () async {
    // Feature 001 must not change how Super records the address it adopted.
    make();
    await container
        .read(settingsProvider.notifier)
        .saveServer(url: '$url/', access: pair, clientFor: via(_Adapter(200)));
    expect(await store.getString('server_url'), url);
    expect(await store.getString('active_url'), url);
    expect(container.read(settingsProvider).activeUrl, url);
  });

  test('a failing connection stores nothing', () async {
    // Defect: a pair saved although the server refused it, which then fails
    // every later request with no explanation.
    make();
    await expectLater(
      container
          .read(settingsProvider.notifier)
          .saveServer(url: url, access: pair, clientFor: via(_Adapter(403))),
      throwsA(isA<AuthFailureException>()),
    );
    expect(await secrets.read(SecretKeys.cfAccessClientId), isNull);
    expect(await secrets.read(SecretKeys.cfAccessClientSecret), isNull);
    expect(container.read(settingsProvider).cloudflareAccess, isNull);
    expect(await store.getString('active_url'), isNull);
  });

  test('load restores the pair after a restart', () async {
    make();
    await secrets.write(SecretKeys.cfAccessClientId, 'id.access');
    await secrets.write(SecretKeys.cfAccessClientSecret, 's3cr3t');
    final loaded = await SuperSettings.load(MemoryKeyValueStore(), secrets);
    expect(loaded.cloudflareAccess, pair);
  });

  test('half a stored pair loads as no pair', () async {
    // Defect: one header alone only produces a rejection.
    make();
    await secrets.write(SecretKeys.cfAccessClientSecret, 's3cr3t');
    final loaded = await SuperSettings.load(MemoryKeyValueStore(), secrets);
    expect(loaded.cloudflareAccess, isNull);
  });

  test(
    'an installation with nothing stored behaves as it did before',
    () async {
      // FR-016 / principle I: no pair, and a config equal to today's.
      make();
      final loaded = await SuperSettings.load(MemoryKeyValueStore(), secrets);
      expect(loaded.cloudflareAccess, isNull);
      final settings = loaded.copyWith(activeUrl: url);
      expect(
        settings.serverConfig,
        ServerConfig(baseUrl: url),
        reason: 'a config with no pair is the same object value as before',
      );
      expect(settings.serverConfig!.accessHeaders, isEmpty);
    },
  );

  test('saving again with no pair removes the stored one', () async {
    // Defect: the user clears the fields and the old token keeps being sent.
    make();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.saveServer(
      url: url,
      access: pair,
      clientFor: via(_Adapter(200)),
    );
    await notifier.saveServer(url: url, clientFor: via(_Adapter(200)));
    expect(await secrets.read(SecretKeys.cfAccessClientId), isNull);
    expect(await secrets.read(SecretKeys.cfAccessClientSecret), isNull);
    expect(container.read(settingsProvider).cloudflareAccess, isNull);
  });

  test('copyWith keeps the pair unless asked to clear it', () {
    final settings = const SuperSettings().copyWith(cloudflareAccess: pair);
    expect(settings.copyWith(quickDownload: true).cloudflareAccess, pair);
    expect(
      settings.copyWith(clearCloudflareAccess: true).cloudflareAccess,
      isNull,
    );
  });

  test('clearing the pair stops the headers with no restart', () async {
    // FR-010: the rebuilt config is what every client is built from, so it
    // is enough that it carries nothing.
    make();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.saveServer(
      url: url,
      access: pair,
      clientFor: via(_Adapter(200)),
    );
    expect(
      container.read(settingsProvider).serverConfig!.accessHeaders,
      isNotEmpty,
    );
    await notifier.saveServer(url: url, clientFor: via(_Adapter(200)));
    expect(
      container.read(settingsProvider).serverConfig!.accessHeaders,
      isEmpty,
    );
    expect(await secrets.read(SecretKeys.cfAccessClientId), isNull);
    expect(await secrets.read(SecretKeys.cfAccessClientSecret), isNull);
  });
}
