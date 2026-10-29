import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/features/downloads/done_check.dart';
import 'package:metube_desktop/shell/ember_dialog.dart';
import 'package:metube_desktop/shell/panel_reveal.dart';
import 'package:mt_ui/mt_ui.dart';

/// The motion that replaced cuts: the side panel, the dialogs and the
/// arrival check. Each moves, and each stands still for anyone who turned
/// animations off in Windows.
void main() {
  // One theme for every pump, or the app's own theme would animate between
  // two equal copies and read as motion.
  final theme = mtDesktopTheme(MTVariant.superApp, Brightness.light);

  Widget host(Widget child, {bool still = false}) => MaterialApp(
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Scaffold(body: Row(children: [const Spacer(), child])),
    ),
  );

  const panel = SizedBox(width: 200, height: 100, key: ValueKey('panel'));

  testWidgets('**the guard**: the side panel closes in motion, keeping what '
      'it shows until it is gone', (tester) async {
    await tester.pumpWidget(host(const PanelReveal(shown: true, child: panel)));
    expect(find.byKey(const ValueKey('panel')), findsOneWidget);

    await tester.pumpWidget(
      host(const PanelReveal(shown: false, child: panel)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    // Still on its way out, narrower than its own width.
    expect(find.byKey(const ValueKey('panel')), findsOneWidget);
    expect(tester.getSize(find.byType(PanelReveal)).width, lessThan(200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('panel')), findsNothing);

    await tester.pumpWidget(host(const PanelReveal(shown: true, child: panel)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(find.byType(PanelReveal)).width, lessThan(200));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(PanelReveal)).width, 200);
  });

  testWidgets('with animations off the panel is there or not in one frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const PanelReveal(shown: false, child: panel), still: true),
    );
    await tester.pumpWidget(
      host(const PanelReveal(shown: true, child: panel), still: true),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(PanelReveal)).width, 200);
  });

  testWidgets('**the guard**: a dialog grows from a little smaller as it '
      'fades in', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showEmberDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(content: Text('Hello')),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final scale = tester.widget<ScaleTransition>(
      find
          .ancestor(
            of: find.text('Hello'),
            matching: find.byType(ScaleTransition),
          )
          .first,
    );
    expect(scale.scale.value, inExclusiveRange(0.96, 1));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('the arrival check draws itself, or appears whole when '
      'animations are off', (tester) async {
    await tester.pumpWidget(host(const DoneCheck()));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      host(const DoneCheck(key: ValueKey(2)), still: true),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
