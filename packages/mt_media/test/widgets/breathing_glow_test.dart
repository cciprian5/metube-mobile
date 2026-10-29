import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The glow behind the cover** (2026-09-24).
///
/// What matters is not how it looks — that is judged by eye on the phone —
/// but when it moves: only while playing, never for someone who turned
/// animations off, and never asking for frames once it has settled.
void main() {
  // One theme for every pump: a new one each time would make the app's
  // own theme animate between them, which is not the glow moving.
  final theme = mtTheme(MTVariant.superApp, Brightness.light);

  Widget host(
    ValueNotifier<bool> playing, {
    bool reduceMotion = false,
    Object? clip,
  }) => MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(
        child: MTBreathingGlow(
          playing: playing,
          size: 200,
          clip: clip,
          child: const SizedBox.square(dimension: 200),
        ),
      ),
    ),
  );

  group('the embers (the owner\'s pick, 2026-09-24)', () {
    test('at rest both sit at the centre: the still halo of before', () {
      final (large, small) = MTBreathingGlow.embersAt(3.7, 0);

      expect(large.centre, Offset.zero);
      expect(small.centre, Offset.zero);
    });

    test('awake, the large one goes ALL the way round the cover in one '
        'turn — the complaint was a glow that stayed in one place', () {
      var left = false, right = false, up = false, down = false;
      for (var s = 0.0; s < 9; s += 0.25) {
        final c = MTBreathingGlow.embersAt(s, 1).$1.centre;
        left |= c.dx < -0.3;
        right |= c.dx > 0.3;
        up |= c.dy < -0.2;
        down |= c.dy > 0.2;
      }

      expect([left, right, up, down], everyElement(isTrue));
    });

    test('the small one circles the OTHER way, so they meet and part', () {
      double turning(int index) {
        MTEmber at(double s) {
          final (large, small) = MTBreathingGlow.embersAt(s, 1);
          return index == 0 ? large : small;
        }

        final a = at(1).centre, b = at(1.2).centre;
        // The sign of the cross product is the direction of travel.
        return a.dx * b.dy - a.dy * b.dx;
      }

      expect(turning(0).sign, isNot(turning(1).sign));
    });
  });

  testWidgets('paused, it asks for no frames at all', (tester) async {
    final playing = ValueNotifier(false);
    await tester.pumpWidget(host(playing));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('playing, it moves; paused again, it settles and stops', (
    tester,
  ) async {
    final playing = ValueNotifier(true);
    await tester.pumpWidget(host(playing));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.hasRunningAnimations, isTrue);

    playing.value = false;
    await tester.pump();
    await tester.pump(MTBreathingGlow.settle * 2);

    // Stopped for good, not merely slowed: a paused player left on screen
    // would otherwise keep the phone drawing sixty frames a second.
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with animations turned off in Android it never moves, even '
      'while playing', (tester) async {
    final playing = ValueNotifier(true);
    await tester.pumpWidget(host(playing, reduceMotion: true));
    await tester.pump(const Duration(seconds: 3));

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('it sizes to the cover and takes no touches from it', (
    tester,
  ) async {
    final playing = ValueNotifier(true);
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.dark),
        home: Center(
          child: MTBreathingGlow(
            playing: playing,
            size: 200,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tapped++,
              child: const SizedBox.square(dimension: 200),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.getSize(find.byType(MTBreathingGlow)), const Size(200, 200));
    await tester.tapAt(tester.getCenter(find.byType(MTBreathingGlow)));
    expect(tapped, 1);
    playing.value = false;
    await tester.pump(MTBreathingGlow.settle * 2);
  });

  testWidgets('**the guard**: on a computer the embers are drawn from a '
      'light made once, as a gradient for every pixel of every frame was '
      'too slow there; a phone keeps the gradient', (tester) async {
    final playing = ValueNotifier(false);
    Finder embers() => find.descendant(
      of: find.byType(MTBreathingGlow),
      matching: find.byType(CustomPaint),
    );
    await tester.pumpWidget(host(playing));
    expect(
      embers(),
      paints
        ..circle()
        ..circle(),
    );
    await tester.pumpWidget(MTDesktopApp(child: host(playing)));
    expect(
      embers(),
      paints
        ..drawImageRect()
        ..drawImageRect(),
    );
  });

  group('the deeper breath (2026-10-29)', () {
    test('a deeper breath widens and strengthens both embers', () {
      final (large, small) = MTBreathingGlow.embersAt(0, 1);
      final (deepLarge, deepSmall) = MTBreathingGlow.embersAt(
        0,
        1,
        deeper: 0.6,
      );
      expect(deepLarge.radius, greaterThan(large.radius));
      expect(deepSmall.strength, greaterThan(small.strength));
    });

    testWidgets('a new clip while playing breathes once, then settles', (
      tester,
    ) async {
      final playing = ValueNotifier(true);
      await tester.pumpWidget(host(playing, clip: 'a'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(host(playing, clip: 'b'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      playing.value = false;
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('**the guard**: the phone glow, given no clip, stays as it '
        'was (no deeper breath)', (tester) async {
      final playing = ValueNotifier(true);
      await tester.pumpWidget(host(playing));
      await tester.pump(const Duration(seconds: 3));
      playing.value = false;
      await tester.pumpAndSettle();
      // A rebuild with no clip, as the phones' player does on every frame
      // of its own, starts nothing.
      await tester.pumpWidget(host(playing));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('**the guard**: the cover shadow can be turned off', (
    tester,
  ) async {
    BoxShadow? shadowOf(bool on) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MTTiltedArtwork),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration is BoxDecoration,
              ),
            )
            .first,
      );
      final list = (box.decoration! as BoxDecoration).boxShadow;
      return list == null || list.isEmpty ? null : list.first;
    }

    const item = PlaylistItem(canonicalUrl: 'u', title: 't');
    for (final on in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          home: Center(
            child: MTTiltedArtwork(item: item, size: 100, shadow: on),
          ),
        ),
      );
      expect(shadowOf(on) != null, on);
    }
  });
}
