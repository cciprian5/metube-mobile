import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/pill.dart';
import 'package:mt_ui/mt_ui.dart';

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool selected = false;

  @override
  Widget build(BuildContext context) => EmberPill(
    label: 'YouTube · 119',
    selected: selected,
    onTap: () => setState(() => selected = !selected),
  );
}

void main() {
  testWidgets(
    '**the guard**: a pill chosen by a mouse click stays dark under the pointer',
    (tester) async {
      // Seen on the real window: the light hover fill from before the
      // click stayed over the newly chosen pill and hid its cream label.
      const boundary = Key('pill');
      await tester.pumpWidget(
        MTDesktopApp(
          child: MaterialApp(
            theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
            home: const Scaffold(
              body: Center(
                child: RepaintBoundary(key: boundary, child: _Host()),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final at = tester.getCenter(find.byType(EmberPill));
      await mouse.moveTo(at);
      await tester.pumpAndSettle();
      await mouse.down(at);
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.up();
      await tester.pumpAndSettle();

      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      final darkShare = await tester.runAsync(() async {
        final image = await render.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        // The pill's middle row, left edge to right edge: how much of it
        // is the ink fill rather than cream.
        final y = image.height ~/ 2;
        var dark = 0;
        for (var x = 0; x < image.width; x++) {
          final i = (y * image.width + x) * 4;
          final light =
              (bytes!.getUint8(i) +
                  bytes.getUint8(i + 1) +
                  bytes.getUint8(i + 2)) /
              765;
          if (light < 0.5) dark++;
        }
        return dark / image.width;
      });
      // The chosen pill is mostly ink around its label; the cream that
      // covered it left almost nothing dark.
      expect(darkShare, greaterThan(0.25));
    },
  );
}
