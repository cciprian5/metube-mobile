import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// The desktop tooltip: shown on a resting pointer, gone when it leaves or
/// clicks, silent to a screen reader, and **never an `OverlayPortal`**,
/// whose grafted node broke Windows' accessibility tree when two met in
/// one node.
void main() {
  Future<TestGesture> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MTDesktopApp(
        child: MaterialApp(
          theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MTShortcutTooltip(
                    message: 'Play',
                    shortcut: 'Space',
                    child: IconButton(onPressed: () {}, icon: const Text('▶')),
                  ),
                  MTShortcutTooltip(
                    message: 'Next',
                    child: IconButton(onPressed: () {}, icon: const Text('⏭')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    return mouse;
  }

  testWidgets('**the guard**: shown after the wait, with its key, and no '
      'OverlayPortal anywhere', (tester) async {
    final mouse = await open(tester);
    expect(find.byType(OverlayPortal), findsNothing);
    await mouse.moveTo(tester.getCenter(find.text('▶')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Play', findRichText: true), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('Play', findRichText: true), findsOneWidget);
    expect(find.text('Space'), findsOneWidget);
    expect(find.byType(OverlayPortal), findsNothing);
  });

  testWidgets('it goes when the pointer leaves or clicks', (tester) async {
    final mouse = await open(tester);
    await mouse.moveTo(tester.getCenter(find.text('▶')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Play', findRichText: true), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.textContaining('Play', findRichText: true), findsNothing);

    await mouse.moveTo(tester.getCenter(find.text('⏭')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Next', findRichText: true), findsOneWidget);
    await mouse.down(tester.getCenter(find.text('⏭')));
    await tester.pump();
    expect(find.textContaining('Next', findRichText: true), findsNothing);
    await mouse.up();
  });

  testWidgets('silent to a screen reader: the control keeps its own name', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final mouse = await open(tester);
    await mouse.moveTo(tester.getCenter(find.text('▶')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Play'), findsNothing);
    semantics.dispose();
  });
}
