import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/main.dart';

void main() {
  testWidgets('the shell starts on the Super palette', (tester) async {
    await tester.pumpWidget(const EmberApp());

    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).colorScheme.primary, const Color(0xFFC25E2E));
  });
}
