import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/shell_layout.dart';
import 'package:mt_core/mt_core.dart';

void main() {
  late MemoryKeyValueStore kv;
  late ShellLayoutStore store;

  setUp(() {
    kv = MemoryKeyValueStore();
    store = ShellLayoutStore(store: kv, mutex: PrefsMutex());
  });

  test('a first start shows every column', () async {
    expect(await store.read(), const ShellLayout());
  });

  test('folded columns stay folded after a restart', () async {
    const folded = ShellLayout(sidebarNarrow: true, panelHidden: true);
    await store.write(folded);
    expect(await store.read(), folded);
    await store.write(folded.copyWith(panelHidden: false));
    expect(await store.read(), const ShellLayout(sidebarNarrow: true));
  });

  test('a damaged entry reads as the default layout', () async {
    for (final junk in ['{', '7', '{"sidebarNarrow":"yes"}']) {
      await kv.setString(ShellLayoutStore.key, junk);
      expect(await store.read(), const ShellLayout(), reason: junk);
    }
  });
}
