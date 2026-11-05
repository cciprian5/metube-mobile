import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/drop_frame.dart';
import 'package:mt_ui/mt_ui.dart';

/// WCAG contrast of [a] over [b].
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  for (final (name, p) in [
    ('day', MTPalette.superDay),
    ('night', MTPalette.superNight),
  ]) {
    test('**the guard**: by $name the drop frame keeps the ground\'s '
        'lightness, and its words and edge stand out on it', () {
      final wash = Color.alphaBlend(dropWash(p), p.bg);
      // Night stays night: no orange sheet over the window.
      expect(
        (wash.computeLuminance() - p.bg.computeLuminance()).abs(),
        lessThan(0.15),
      );
      expect(_contrast(p.accentInk, wash), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.accent, wash), greaterThanOrEqualTo(3));
    });
  }
}
