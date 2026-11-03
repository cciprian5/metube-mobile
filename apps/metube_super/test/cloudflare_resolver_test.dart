import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// The endpoint resolver follows the Cloudflare pair (feature 001, T023).
///
/// The provider selects a few settings rather than watching all of them,
/// because rebuilding it re-probes every endpoint. Adding the pair to that
/// selection must not turn it back into "rebuild on any change".
void main() {
  final pair = CloudflareAccess(clientId: 'id.access', clientSecret: 's3cr3t');

  late ProviderContainer container;

  ProviderContainer make() {
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a changed pair rebuilds the resolver', () {
    // Defect: probes keep using the old token, so an endpoint reads as
    // "rejected" right after the user fixed the pair.
    make();
    final before = container.read(endpointResolverProvider);
    container.read(settingsProvider.notifier).state = container
        .read(settingsProvider)
        .copyWith(cloudflareAccess: pair);
    expect(container.read(endpointResolverProvider), isNot(same(before)));
  });

  test('a removed pair rebuilds it too', () {
    make();
    container.read(settingsProvider.notifier).state = container
        .read(settingsProvider)
        .copyWith(cloudflareAccess: pair);
    final withPair = container.read(endpointResolverProvider);
    container.read(settingsProvider.notifier).state = container
        .read(settingsProvider)
        .copyWith(clearCloudflareAccess: true);
    expect(container.read(endpointResolverProvider), isNot(same(withPair)));
  });

  test('an unrelated setting does not rebuild it', () {
    // The reason the provider uses `select`: changing the theme or the
    // quality re-probed every endpoint while the user stood in the network
    // screen.
    make();
    container.read(settingsProvider.notifier).state = container
        .read(settingsProvider)
        .copyWith(cloudflareAccess: pair);
    final before = container.read(endpointResolverProvider);
    final settings = container.read(settingsProvider);
    container.read(settingsProvider.notifier).state = settings.copyWith(
      quickDownload: true,
      wifiOnly: true,
      localeCode: 'ar',
    );
    expect(container.read(endpointResolverProvider), same(before));
  });

  test('an equal pair does not rebuild it', () {
    // A save that wrote the same values again must not re-probe.
    make();
    container.read(settingsProvider.notifier).state = container
        .read(settingsProvider)
        .copyWith(cloudflareAccess: pair);
    final before = container.read(endpointResolverProvider);
    container.read(settingsProvider.notifier).state = container
        .read(settingsProvider)
        .copyWith(
          cloudflareAccess: CloudflareAccess(
            clientId: 'id.access',
            clientSecret: 's3cr3t',
          ),
        );
    expect(container.read(endpointResolverProvider), same(before));
  });
}
