import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/main.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  testWidgets('the shell starts on the Super palette', (tester) async {
    await tester.pumpWidget(const EmberApp());

    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).colorScheme.primary, const Color(0xFFC25E2E));
  });

  testWidgets('the shell declares itself the Windows app', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const EmberApp());

    final context = tester.element(find.byType(Scaffold));
    expect(context.windowClass, MTWindowClass.desktop);
  });
}
