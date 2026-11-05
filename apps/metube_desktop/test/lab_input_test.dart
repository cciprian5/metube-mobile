import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/lab_hover.dart';

void main() {
  test('lab clicks read a point and a second, and skip what is broken', () {
    final taps = labTapsFrom(['--lab-tap=695,461@9;oops;10,20@x;5.5,6@3']);
    expect(taps, [
      (const Offset(695, 461), const Duration(seconds: 9)),
      (const Offset(5.5, 6), const Duration(seconds: 3)),
    ]);
    expect(labTapsFrom(['--lab-keys=c@6']), isEmpty);
  });

  test('lab keys know C, for the subtitles', () {
    final keys = labKeysFrom(['--lab-keys=c@6;nope@7']);
    expect(keys, hasLength(1));
    expect(keys.single.$1, LogicalKeyboardKey.keyC);
    expect(keys.single.$3, const Duration(seconds: 6));
    expect(keys.single.held, isEmpty);
  });

  test('lab keys can be pressed with Ctrl and Shift held', () {
    final keys = labKeysFrom(['--lab-keys=ctrl+shift+c@20;ctrl+c@21;alt+c@22']);
    expect(keys, hasLength(2));
    expect(keys.first.held.map((k) => k.$1), [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.shiftLeft,
    ]);
    expect(keys.last.held.map((k) => k.$1), [LogicalKeyboardKey.controlLeft]);
  });

  test('lab wheel turns read a point, a distance and a second', () {
    expect(labScrollsFrom(['--lab-scroll=700,500,1200@10;bad@1']), [
      (const Offset(700, 500), 1200.0, const Duration(seconds: 10)),
    ]);
  });
}
