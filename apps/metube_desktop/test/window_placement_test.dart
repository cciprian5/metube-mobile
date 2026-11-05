import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/platform/window_placement.dart';
import 'package:mt_core/mt_core.dart';

void main() {
  // A 1920x1080 primary with its taskbar, and a second screen to its right.
  const primary = Rect.fromLTWH(0, 0, 1920, 1032);
  const second = Rect.fromLTWH(1920, 0, 1280, 984);

  WindowPlacement at(Rect r, {bool max = false}) =>
      WindowPlacement(bounds: r, maximized: max);

  test('a first start is 1280x800 in the middle of the primary screen', () {
    final r = placeWindow(saved: null, workAreas: [primary], primary: primary);
    expect(r.size, firstWindowSize);
    expect(r.center, primary.center);
  });

  test('a window the user can reach opens where it was left', () {
    const left = Rect.fromLTWH(2000, 50, 1100, 700);
    expect(
      placeWindow(
        saved: at(left),
        workAreas: [primary, second],
        primary: primary,
      ),
      left,
    );
  });

  test('**the guard**: the screen it was on is gone, so it is centred', () {
    // Saved on the second screen, which is now unplugged.
    const left = Rect.fromLTWH(2000, 50, 1100, 700);
    final r = placeWindow(
      saved: at(left),
      workAreas: [primary],
      primary: primary,
    );
    expect(r.size, left.size);
    expect(r.center, primary.center);
  });

  test('a title bar above every screen cannot be grabbed: centred', () {
    // The body shows, but the top edge is off the top of the screen.
    const left = Rect.fromLTWH(300, -200, 1100, 700);
    final r = placeWindow(
      saved: at(left),
      workAreas: [primary],
      primary: primary,
    );
    expect(r.center, primary.center);
  });

  test('a sliver of title bar is not enough to drag it back', () {
    const left = Rect.fromLTWH(1850, 100, 1100, 700); // 70 px showing
    final r = placeWindow(
      saved: at(left),
      workAreas: [primary],
      primary: primary,
    );
    expect(r.center, primary.center);
  });

  test('a window overhanging its screen is pulled back inside', () {
    const left = Rect.fromLTWH(1500, 600, 1100, 700);
    final r = placeWindow(
      saved: at(left),
      workAreas: [primary],
      primary: primary,
    );
    expect(r.size, left.size);
    expect(primary.contains(r.topLeft), isTrue);
    expect(r.right, lessThanOrEqualTo(primary.right));
    expect(r.bottom, lessThanOrEqualTo(primary.bottom));
  });

  test('a size from a larger monitor shrinks to the laptop it opens on', () {
    const laptop = Rect.fromLTWH(0, 0, 1093, 566 + 120);
    const big = Rect.fromLTWH(0, 0, 2400, 1300);
    final r = placeWindow(saved: at(big), workAreas: [laptop], primary: laptop);
    expect(r, laptop);
  });

  test('nothing opens smaller than the minimum, even on a tiny screen', () {
    const tiny = Rect.fromLTWH(0, 0, 800, 500);
    final r = placeWindow(saved: null, workAreas: [tiny], primary: tiny);
    expect(r.size, minimumWindowSize);
    expect(r.topLeft, Offset.zero);
  });

  group('the store', () {
    late MemoryKeyValueStore kv;
    late WindowPlacementStore store;

    setUp(() {
      kv = MemoryKeyValueStore();
      store = WindowPlacementStore(store: kv, mutex: PrefsMutex());
    });

    test('keeps the normal bounds and the maximized flag', () async {
      const r = Rect.fromLTWH(12, 34, 1100, 700);
      await store.write(at(r, max: true));
      final back = await store.read();
      expect(back!.bounds, r);
      expect(back.maximized, isTrue);
    });

    test('a damaged entry reads as nothing saved, not a crash', () async {
      expect(await store.read(), isNull);
      for (final junk in ['{', '[]', '{"x":1}', '{"x":0,"y":0,"w":0,"h":9}']) {
        await kv.setString(WindowPlacementStore.key, junk);
        expect(await store.read(), isNull, reason: junk);
      }
    });
  });
}
