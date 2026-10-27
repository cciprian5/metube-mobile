import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/data/update_data.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';

import 'support/shell_harness.dart';

/// Windows' file dialogs, answered by the test.
class _Dialogs extends NoFolders {
  List<(String, List<int>)> chosen = const [];
  String? savedName;
  String? savedText;

  @override
  Future<List<(String, List<int>)>> openFiles({
    required List<String> extensions,
  }) async => chosen;

  @override
  Future<String?> saveText({required String name, required String text}) async {
    savedName = name;
    savedText = text;
    return 'C:\\Users\\me\\$name';
  }
}

List<int> _cookies(String domain) => utf8.encode(
  '# Netscape HTTP Cookie File\n'
  '$domain\tTRUE\t/\tTRUE\t1893456000\tsid\tsecret-$domain\n',
);

/// A release page as GitHub would answer for one tag.
String _release(String body) => jsonEncode({'body': body});

/// Lets real file reads finish. Each step of one resumes on the test's
/// clock and starts the next on the real one, so the two take turns.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory root;
  late MTLogger logger;
  late _Dialogs dialogs;
  final copied = <String>[];
  final asked = <Uri>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync('ember_settings_');
    logger = MTLogger(filePath: '${root.path}/ember.log');
    dialogs = _Dialogs();
    copied.clear();
    asked.clear();
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<ShellHarness> open(
    WidgetTester tester, {
    String? to,
    String version = '0.2.0',
    bool atStart = false,
    void Function(MemoryKeyValueStore store)? before,
  }) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = ShellHarness(
      library: const [],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      overrides: [
        loggerProvider.overrideWithValue(logger),
        desktopFoldersProvider.overrideWithValue(dialogs),
        installedVersionProvider.overrideWith((ref) async => version),
        offerWhatsNewProvider.overrideWithValue(atStart),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(
            assetMarker: 'ember',
            fetch: (uri) async {
              asked.add(uri);
              return _release(
                '## Fixed\n- The palette opens at once.\n\n---\n\n'
                '## بالعربية\n- اللوحة تفتح فوراً.',
              );
            },
          ),
        ),
      ],
    );
    before?.call(h.store);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    if (to != null) {
      GoRouter.of(tester.element(find.byType(EmberSidebar))).go(to);
      await tester.pumpAndSettle();
    }
    return h;
  }

  group('the log', () {
    testWidgets('**the guard**: saved and copied without the server '
        'address, whichever way it leaves', (tester) async {
      await tester.runAsync(
        () => logger.log('history from http://192.168.1.10:8081/history'),
      );
      await open(tester, to: '/settings/logs');
      // The log is a real file, read off the test's fake clock.
      await settle(tester);
      // On screen the log is as written: only what leaves is cleaned.
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data!.contains('192.168.1.10'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Save to a file'));
      await settle(tester);
      expect(dialogs.savedName, startsWith('metube_ember_logs_'));
      expect(dialogs.savedText, contains('history from'));
      expect(dialogs.savedText, isNot(contains('192.168.1.10')));

      await tester.tap(find.text('Copy'));
      await settle(tester);
      expect(copied.single, isNot(contains('192.168.1.10')));
    });
  });

  group('cookies', () {
    testWidgets('**the guard**: files chosen together go as one file, and '
        'the notice names each site', (tester) async {
      final h = await open(tester, to: '/settings/cookies');
      expect(find.text('The server has no cookies'), findsOneWidget);
      expect(find.text('Delete the cookies'), findsNothing);
      dialogs.chosen = [
        ('youtube.txt', _cookies('.youtube.com')),
        ('instagram.txt', _cookies('.instagram.com')),
      ];
      await tester.tap(find.text('Choose cookies files'));
      await tester.pumpAndSettle();
      final (name, bytes) = h.api.cookieUploads.single;
      expect(name, 'cookies.txt');
      expect(
        utf8.decode(bytes),
        allOf(contains('youtube'), contains('instagram')),
      );
      expect(find.textContaining('youtube.com'), findsWidgets);
      expect(find.text('The server has cookies'), findsOneWidget);
      expect(find.text('Delete the cookies'), findsOneWidget);
    });
  });

  group("what's new", () {
    testWidgets('About shows the version and its notes on request', (
      tester,
    ) async {
      await open(tester, to: '/settings/about');
      expect(find.text('Version 0.2.0'), findsOneWidget);
      await tester.tap(find.text("What's new in this version"));
      await tester.pumpAndSettle();
      expect(find.text("What's new in 0.2.0"), findsOneWidget);
      expect(find.textContaining('The palette opens at once.'), findsOneWidget);
      expect(asked.single.path, endsWith('/releases/tags/v0.2.0'));
    });

    testWidgets('**the guard**: a first start only records the version; a '
        'newer one shows its notes once', (tester) async {
      final h = await open(tester, atStart: true);
      expect(find.textContaining("What's new"), findsNothing);
      expect(await h.store.getString(UpdatePrefs.lastSeenVersionKey), '0.2.0');
    });

    testWidgets('after an update the notes come up by themselves', (
      tester,
    ) async {
      final h = await open(
        tester,
        atStart: true,
        version: '0.3.0',
        before: (store) =>
            store.setString(UpdatePrefs.lastSeenVersionKey, '0.2.0'),
      );
      expect(find.text("What's new in 0.3.0"), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(await h.store.getString(UpdatePrefs.lastSeenVersionKey), '0.3.0');
    });
  });
}
