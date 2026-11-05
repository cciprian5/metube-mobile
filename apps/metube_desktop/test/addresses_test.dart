import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/addresses_data.dart';
import 'package:mt_core/mt_core.dart';

void main() {
  test('**the guard**: an address saved twice is listed once', () async {
    final store = MemoryKeyValueStore();
    await store.setStringList('ember_server_addresses', const [
      'http://nas:8086',
      'https://tunnel.example.com',
      'http://nas:8086',
    ]);
    await store.setString('ember_server_active', 'http://nas:8086');
    final read = await AddressesStore(store: store, mutex: PrefsMutex()).read();
    expect(read.urls, ['http://nas:8086', 'https://tunnel.example.com']);
    expect(read.active, 'http://nas:8086');
  });
}
