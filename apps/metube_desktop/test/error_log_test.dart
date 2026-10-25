import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/platform/error_log.dart';

void main() {
  testWidgets('**the guard**: an overflow, which carries no stack, is logged '
      'with the widget and the file it was written in', (tester) async {
    final caught = <FlutterErrorDetails>[];
    final present = FlutterError.onError;
    FlutterError.onError = caught.add;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 50,
            child: Row(children: [SizedBox(width: 65, height: 10)]),
          ),
        ),
      ),
    );
    FlutterError.onError = present;

    final overflow = caught.single;
    expect(overflow.exceptionAsString(), contains('overflowed by 15 pixels'));
    final place = errorPlace(overflow);
    expect(place, contains('Row'));
    expect(place, contains('error_log_test.dart'));
  });
}
