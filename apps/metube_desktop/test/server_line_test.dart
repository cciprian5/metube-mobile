import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/server_release.dart';
import 'package:metube_desktop/shell/server_line.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The sidebar's foot announces a server only when something is wrong.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Future<HistoryResponse?> Function() history,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConfigProvider.overrideWithValue(
            ServerConfig(baseUrl: 'http://nas:8081'),
          ),
          historyProvider.overrideWith((ref) => history()),
          serverReleaseProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtDesktopTheme(MTVariant.superApp, Brightness.light),
          home: const Scaffold(
            body: SizedBox(width: 240, child: SidebarServerLine(narrow: false)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('**the guard**: a server that answers gets a quiet mark, no '
      'coloured dot', (tester) async {
    await pump(tester, () async => null);
    expect(find.byKey(const ValueKey('server-dot')), findsNothing);
    expect(find.byKey(const ValueKey('server-quiet')), findsOneWidget);
  });

  testWidgets('a server that does not answer gets its dot', (tester) async {
    await pump(tester, () async => throw Exception('down'));
    expect(find.byKey(const ValueKey('server-dot')), findsOneWidget);
  });
}
