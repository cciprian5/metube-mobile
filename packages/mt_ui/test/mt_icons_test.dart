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

  Widget framed(Widget child, {TextDirection dir = TextDirection.ltr}) =>
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: Directionality(
          textDirection: dir,
          child: Center(child: child),
        ),
      );

  testWidgets('**the guard**: the reading arrows turn in Arabic, nothing '
      'else does', (tester) async {
    Finder flip() => find.descendant(
      of: find.byType(MTIcon),
      matching: find.byType(Transform),
    );
    const arrow = MTIcon(MTIcons.forward, matchTextDirection: true);
    await tester.pumpWidget(framed(arrow, dir: TextDirection.rtl));
    expect(flip(), findsOneWidget);
    await tester.pumpWidget(framed(arrow));
    expect(flip(), findsNothing);
    await tester.pumpWidget(
      framed(const MTIcon(MTIcons.transcript), dir: TextDirection.rtl),
    );
    expect(flip(), findsNothing);
  });

  testWidgets('a shadow draws a blurred copy beneath the icon', (tester) async {
    await tester.pumpWidget(
      framed(
        const MTIcon(
          MTIcons.moreVert,
          shadows: [Shadow(color: Color(0x99000000), blurRadius: 5)],
        ),
      ),
    );
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(2));
  });

  testWidgets('outside a Wahaj theme the icon still draws', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MTIcon(MTIcons.cloud, color: Color(0xFF445566)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('**the guard**: what Flutter draws by itself takes the Wahaj '
      'glyphs too: the back arrow, the chosen segment', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: const Scaffold(),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('A')),
              ButtonSegment(value: 1, label: Text('B')),
            ],
            selected: const {0},
            onSelectionChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final names = [
      for (final i in tester.widgetList<MTIcon>(find.byType(MTIcon)))
        i.icon.name,
    ];
    expect(names, containsAll(['back', 'check']));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('**the guard**: a parent that forces a larger box widens the '
      'box, never the glyph', (tester) async {
    // An input field's prefix forces 48 by 48; the lens grew to fill it.
    await tester.pumpWidget(
      framed(
        const SizedBox.square(
          dimension: 48,
          child: MTIcon(MTIcons.search, size: 20),
        ),
      ),
    );
    expect(tester.getSize(find.byType(SvgPicture)), const Size(20, 20));
  });

  testWidgets("a disabled button's dimmed icon theme dims the glyph", (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      framed(
        IconTheme(
          data: const IconThemeData(color: Color(0xFF112233), opacity: 0.5),
          child: Builder(
            builder: (c) {
              ctx = c;
              return const MTIcon(MTIcons.close);
            },
          ),
        ),
      ),
    );
    expect(const MTIcon(MTIcons.close).svgIn(ctx), contains('#11223380'));
  });
}
