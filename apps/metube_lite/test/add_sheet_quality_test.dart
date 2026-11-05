import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/home/add_flow.dart';
import 'package:metube_lite/features/home/link_preview_view.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **The heights in Lite's add sheet** (owner's decisions of 2026-11-04): a
/// ceiling on every video site, with 360 offered here alone so a family
/// phone can keep its downloads small, and none for sound alone.
void main() {
  late _Engine engine;

  Widget host(String url) {
    engine = _Engine();
    return ProviderScope(
      overrides: _overrides(engine),
      child: MaterialApp.router(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () =>
                        openAddSheet(context, ref, initialUrl: url),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            GoRoute(path: '/batch', builder: (_, _) => const Scaffold()),
          ],
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, String url) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(url));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('**the guard**: 360 is offered, and goes with the download', (
    tester,
  ) async {
    await open(tester, 'https://www.youtube.com/watch?v=jNQXAC9IVRw');
    await tester.tap(find.text('Up to 360p'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start download'));
    await tester.pumpAndSettle();
    expect(engine.qualities, [Quality.q360]);
  });

  testWidgets('another video site offers the heights too', (tester) async {
    await open(tester, 'https://www.tiktok.com/@u/video/7301234567890123456');
    expect(find.text('Up to 720p'), findsOneWidget);
    expect(find.text('Up to 360p'), findsOneWidget);
  });

  testWidgets('sound alone offers no heights', (tester) async {
    await open(tester, 'https://soundcloud.com/artist/track');
    expect(find.text('Up to 720p'), findsNothing);
    expect(find.text('Up to 360p'), findsNothing);
  });

  testWidgets('the sheet with its six choices holds on every device', (
    tester,
  ) async {
    await expectNoOverflow(tester, () => const _Opened());
  });
}

List<Override> _overrides(DownloadEngine? engine) => [
  keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
  secretStoreProvider.overrideWithValue(MemorySecretStore()),
  prefsMutexProvider.overrideWithValue(PrefsMutex()),
  initialSettingsProvider.overrideWithValue(const LiteSettings()),
  loggerProvider.overrideWithValue(
    MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
  ),
  downloadEngineProvider.overrideWithValue(engine),
  linkPreviewResolverProvider.overrideWithValue(
    ClipPreviewResolver(httpGet: (_) async => '{}'),
  ),
];

/// The sheet, opened once per size by the device matrix.
class _Opened extends StatelessWidget {
  const _Opened();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: _overrides(null),
    child: MaterialApp.router(
      theme: mtTheme(MTVariant.lite, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const _OpensSheet())],
      ),
    ),
  );
}

class _OpensSheet extends ConsumerStatefulWidget {
  const _OpensSheet();

  @override
  ConsumerState<_OpensSheet> createState() => _OpensSheetState();
}

class _OpensSheetState extends ConsumerState<_OpensSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => openAddSheet(
        context,
        ref,
        initialUrl: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

class _Engine implements DownloadEngine {
  final qualities = <Quality>[];

  @override
  DownloadTask submit(
    String url,
    Quality quality, {
    bool isBatchMember = false,
    String? folder,
  }) {
    qualities.add(quality);
    return DownloadTask(inputUrl: url, quality: quality, folder: folder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
