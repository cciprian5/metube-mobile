import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/volume.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';

import 'support/shell_harness.dart';

LibraryItem _item(String id, int day) => LibraryItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: 'Clip $id',
  onServer: true,
  timestamp: DateTime(2026, 10, day),
);

/// An arrow is one thing at a time: the volume or seeking when nothing is
/// chosen, the next control when the keyboard is walking the window. Both
/// at once raised the volume while the focus moved.
void main() {
  Future<(ShellHarness, HeldVolume)> open(WidgetTester tester) async {
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
    final volume = HeldVolume(50);
    final h = ShellHarness(
      library: [for (var i = 1; i <= 8; i++) _item('clip000000$i', i)],
      overrides: [volumeControlProvider.overrideWithValue(volume)],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.player.showPlaying([
      const PlaylistItem(
        canonicalUrl: 'https://youtu.be/playing0000',
        title: 'P',
      ),
    ]);
    await tester.pump();
    return (h, volume);
  }

  bool onAControl() => switch (FocusManager.instance.primaryFocus) {
    null => false,
    final FocusScopeNode _ => false,
    final node => node.context != null,
  };

  testWidgets('**the guard**: with nothing chosen, ↑ raises the volume and '
      'moves nothing', (tester) async {
    final (_, volume) = await open(tester);
    expect(onAControl(), isFalse);
    final before = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(volume.level, 55);
    expect(FocusManager.instance.primaryFocus, same(before));
  });

  testWidgets('**the guard**: walking the window with the keys, the arrows '
      'move and leave the volume and the clip alone', (tester) async {
    final (h, volume) = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(onAControl(), isTrue);
    final from = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(volume.level, 50);
    expect(FocusManager.instance.primaryFocus, isNot(same(from)));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(h.player.sought, isNull);
  });
}
