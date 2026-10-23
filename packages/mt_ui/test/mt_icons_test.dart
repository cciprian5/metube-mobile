import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  Future<void> pumpAll(WidgetTester tester, ThemeData theme) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Wrap(children: [for (final i in MTIcons.all) MTIcon(i)]),
        ),
      );

  testWidgets('every icon draws without an error, day and night', (
    tester,
  ) async {
    for (final b in Brightness.values) {
      await pumpAll(tester, mtTheme(MTVariant.superApp, b));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$b');
      expect(find.byType(SvgPicture), findsNWidgets(MTIcons.all.length));
    }
  });

  test('**the guard**: no icon keeps a dash written against pathLength', () {
    // flutter_svg ignores pathLength: a gap measured against it lands in the
    // wrong place (the search lens closed, the heart's gap moved). The
    // generator converts such dashes to absolute lengths.
    for (final icon in MTIcons.all) {
      expect(icon.svg, isNot(contains('pathLength')), reason: icon.name);
      expect(icon.svg, isNot(contains('class=')), reason: icon.name);
      expect(icon.svg, isNot(contains('currentColor')), reason: icon.name);
      expect(icon.svg, contains('{ink}'), reason: icon.name);
    }
  });

  testWidgets('the ember follows the palette, the ink the icon theme', (
    tester,
  ) async {
    late BuildContext ctx;
    Future<String> drawn(MTVariant v, Brightness b) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(v, b),
          home: IconTheme(
            data: const IconThemeData(color: Color(0xFF112233)),
            child: Builder(
              builder: (c) {
                ctx = c;
                return const MTIcon(MTIcons.search);
              },
            ),
          ),
        ),
      );
      // MaterialApp animates a theme change; read the colour once it lands.
      await tester.pumpAndSettle();
      return const MTIcon(MTIcons.search).svgIn(ctx);
    }

    final superDay = await drawn(MTVariant.superApp, Brightness.light);
    expect(superDay, contains('#c25e2e'));
    expect(superDay, contains('#112233'));

    final superNight = await drawn(MTVariant.superApp, Brightness.dark);
    expect(superNight, contains('#e0784a'));

    final liteDay = await drawn(MTVariant.lite, Brightness.light);
    expect(liteDay, contains('#2f6d74'));
  });

  test('the alternatives that were not chosen are not generated', () {
    final names = {for (final i in MTIcons.all) i.name};
    expect(names, containsAll(['settings', 'search', 'favorite', 'queue']));
    for (final rejected in ['settings_8', 'sliders', 'knob', 'download_line']) {
      expect(names, isNot(contains(rejected)));
    }
  });
}
