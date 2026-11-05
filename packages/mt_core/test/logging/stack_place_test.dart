import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  const framework = [
    '#0      Element.widget (package:flutter/src/widgets/framework.dart:3666)',
    '#1      Element.dependOnInheritedElement (package:flutter/src/widgets/framework.dart:5090)',
    '#2      Element.dependOnInheritedWidgetOfExactType (package:flutter/src/widgets/framework.dart:5098)',
    '#3      DefaultTextStyle.of (package:flutter/src/widgets/text.dart:190)',
    '#4      TextPainter.layout (package:flutter/src/painting/text_painter.dart:1)',
  ];
  const ours =
      '#5      _CaptionsState._tick (package:mt_media/src/video/mt_captions.dart:88)';

  test('**the guard**: a stack full of framework frames still names the '
      "apps' own frame", () {
    final place = mtStackPlace([...framework, ours, '#6 more'].join('\n'));
    expect(place, contains('mt_captions.dart:88'));
    expect(place.split(' | '), hasLength(5));
  });

  test('an own frame among the first is not repeated', () {
    final place = mtStackPlace(
      [framework[0], ours, ...framework.skip(1)].join('\n'),
    );
    expect('mt_captions.dart'.allMatches(place), hasLength(1));
    expect(place.split(' | '), hasLength(4));
  });

  test('no stack, no place', () {
    expect(mtStackPlace(null), isEmpty);
    expect(mtStackPlace(''), isEmpty);
  });
}
