import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/app.dart';
import 'package:metube_desktop/router.dart';

void main() {
  late GoRouter router;

  Future<PendingPlace> go(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
    return tester.widget<PendingPlace>(find.byType(PendingPlace));
  }

  setUp(() => router = buildEmberRouter());
  tearDown(() => router.dispose());

  testWidgets('the app opens on the library', (tester) async {
    await tester.pumpWidget(ProviderScope(child: EmberApp(router: router)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PendingPlace>(find.byType(PendingPlace)).place,
      'library',
    );
  });

  testWidgets('every place has its address', (tester) async {
    await tester.pumpWidget(ProviderScope(child: EmberApp(router: router)));
    for (final (path, place) in [
      ('/', 'library'),
      (EmberRoutes.search, 'search'),
      (EmberRoutes.playlists, 'playlists'),
      (EmberRoutes.channels, 'channels'),
      (EmberRoutes.settings, 'settings'),
      (EmberRoutes.library, 'library'),
    ]) {
      expect((await go(tester, path)).place, place, reason: path);
    }
  });

  testWidgets('each settings section opens by its own address', (tester) async {
    await tester.pumpWidget(ProviderScope(child: EmberApp(router: router)));
    for (final pane in EmberSettingsPane.values) {
      final shown = await go(tester, pane.route);
      expect((shown.place, shown.argument), ('settings', pane.name));
    }
  });

  testWidgets("a clip's canonical URL survives the trip through its address", (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(child: EmberApp(router: router)));
    const url = 'https://www.youtube.com/watch?v=a1/b&t=30#x';
    final shown = await go(tester, EmberRoutes.item(url));
    expect((shown.place, shown.argument), ('item', url));
  });

  testWidgets('an address that names no place lands on the library', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(child: EmberApp(router: router)));
    expect((await go(tester, '/nowhere/at/all')).place, 'library');
    expect((await go(tester, '/settings/no-such-pane')).place, 'library');
  });

  testWidgets('**the guard**: the shell is built once across navigation', (
    tester,
  ) async {
    // The gate of this phase is music that never stops while moving
    // around, so whatever the shell holds must not be rebuilt from
    // scratch on every change of place.
    var created = 0;
    router.dispose();
    router = buildEmberRouter(
      shell: (_, _, child) =>
          _CountingShell(onCreate: () => created++, child: child),
    );
    await tester.pumpWidget(ProviderScope(child: EmberApp(router: router)));
    await go(tester, EmberRoutes.search);
    await go(tester, EmberRoutes.item('https://x/y'));
    await go(tester, EmberSettingsPane.appearance.route);
    await go(tester, EmberRoutes.library);
    expect(created, 1);
  });
}

class _CountingShell extends StatefulWidget {
  const _CountingShell({required this.onCreate, required this.child});

  final VoidCallback onCreate;
  final Widget child;

  @override
  State<_CountingShell> createState() => _CountingShellState();
}

class _CountingShellState extends State<_CountingShell> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
