import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

/// A later merge between devices keeps the newer resume position, so every
/// write says when it happened; an app passing no clock writes exactly what
/// it wrote before.
void main() {
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  var now = DateTime.utc(2026, 10, 23, 10);

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    now = DateTime.utc(2026, 10, 23, 10);
  });

  PlaybackPositionStore stamped() =>
      PlaybackPositionStore(store: store, mutex: mutex, clock: () => now);

  test('a saved position carries the time it was saved', () async {
    final positions = stamped();
    await positions.save('u', const Duration(seconds: 42));
    expect(await positions.stampOf('u'), now);
  });

  test('finishing is stamped too, so it beats an older position', () async {
    final positions = stamped();
    await positions.save('u', const Duration(seconds: 42));
    now = now.add(const Duration(minutes: 3));

    await positions.save(
      'u',
      const Duration(seconds: 595),
      duration: const Duration(seconds: 600),
    );

    expect(await positions.positionOf('u'), isNull);
    expect(await positions.stampOf('u'), now);
  });

  test('clearing everything clears the stamps as well', () async {
    final positions = stamped();
    await positions.save('u', const Duration(seconds: 42));
    await positions.clearAll();
    expect(await store.keys(), isEmpty);
  });

  test('**the guard**: without a clock only the position is written', () async {
    final positions = PlaybackPositionStore(store: store, mutex: mutex);
    await positions.save('u', const Duration(seconds: 42));

    expect(await store.keys(), ['playback_pos_u']);
    expect(await positions.stampOf('u'), isNull);
  });
}
