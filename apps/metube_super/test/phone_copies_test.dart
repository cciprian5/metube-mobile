import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/home/background_hold.dart';
import 'package:metube_super/features/home/download_watcher.dart'
    show notificationsProvider;
import 'package:metube_super/features/home/notifications.dart';
import 'package:metube_super/features/library/device_pulls.dart';
import 'package:metube_super/features/library/library_actions.dart';
import 'package:metube_super/features/library/share_flow.dart';
import 'package:metube_super/features/library/widgets/phone_pulls.dart';
import 'package:metube_super/features/library/widgets/share_sheet.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/shared/error_text.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

const _mb = 1024 * 1024;

class _Notices extends DownloadNotifications {
  final List<(String, int?)> progress = [];
  final List<int> cancelled = [];

  @override
  Future<void> showProgress(
    int id, {
    required String title,
    required String channelName,
    required int? percent,
    String? body,
  }) async => progress.add((title, percent));

  @override
  Future<void> showResult(
    int id, {
    required String title,
    required String body,
    required String channelName,
    String? payload,
    bool isError = false,
  }) async {}

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// A pull that waits for the test, one gate per file asked for.
class _Pull {
  final List<String> asked = [];
  final Map<String, Completer<void>> gates = {};
  final Map<String, TransferCancel> cancels = {};

  Future<String> call({
    required String serverFilename,
    required String savePath,
    required void Function(int received, int total) onBytes,
    required TransferCancel cancel,
  }) async {
    asked.add(serverFilename);
    cancels[serverFilename] = cancel;
    onBytes(10 * _mb, 100 * _mb);
    await gates[serverFilename]?.future;
    if (cancel.isCancelled) throw const CancelledException();
    await File(savePath).writeAsString('clip');
    return savePath;
  }
}

const _clip = LibraryItem(
  canonicalUrl: 'https://youtu.be/abc',
  title: 'A long talk',
  serverFilename: 'talk.mp4',
  onServer: true,
  sizeBytes: 100 * _mb,
);

void main() {
  late Directory dir;
  late _Notices notices;
  late _Pull pull;
  late List<bool> held;
  late List<String> sent;
  late int? free;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('phone_copies');
    notices = _Notices();
    pull = _Pull();
    held = [];
    sent = [];
    free = null;
  });

  tearDown(() => dir.delete(recursive: true));

  List<Override> overrides() => [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    secretStoreProvider.overrideWithValue(MemorySecretStore()),
    prefsMutexProvider.overrideWithValue(PrefsMutex()),
    initialSettingsProvider.overrideWithValue(const SuperSettings()),
    loggerProvider.overrideWithValue(
      MTLogger(filePath: '${dir.path}/test.log'),
    ),
    notificationsProvider.overrideWithValue(notices),
    phonePullProvider.overrideWithValue(pull.call),
    freeBytesProvider.overrideWithValue((_) async => free),
    mediaDirProvider.overrideWithValue('${dir.path}/media'),
    shareDirProvider.overrideWith((ref) async => '${dir.path}/share'),
    shareSendProvider.overrideWithValue((path) async => sent.add(path)),
    shareForegroundProvider.overrideWithValue(() => true),
    backgroundHoldProvider.overrideWithValue(
      BackgroundHold(
        start: () async {
          held.add(true);
          return true;
        },
        stop: () async => held.add(false),
      ),
    ),
  ];

  ProviderContainer box() {
    final c = ProviderContainer(overrides: overrides());
    addTearDown(c.dispose);
    return c;
  }

  Future<void> untilAsked(int count) async {
    while (pull.asked.length < count) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('one place for every copy to the phone', () {
    test('**the guard**: one copy ending does not wipe the progress of '
        'another of the same clip', () {
      final c = box();
      final pulls = c.read(devicePullsProvider.notifier);
      pulls.begin(PullKind.offline, _clip.canonicalUrl, _clip.title);
      pulls.begin(PullKind.share, _clip.canonicalUrl, _clip.title);
      pulls.report(PullKind.offline, _clip.canonicalUrl, 30, 100);
      pulls.end(PullKind.share, _clip.canonicalUrl);
      expect(c.read(offlinePullProgressProvider)[_clip.canonicalUrl], 0.3);
    });

    test('the same clip is not copied twice for the same reason', () {
      final pulls = box().read(devicePullsProvider.notifier);
      expect(pulls.begin(PullKind.offline, 'u', 't'), isNotNull);
      expect(pulls.begin(PullKind.offline, 'u', 't'), isNull);
      expect(pulls.begin(PullKind.share, 'u', 't'), isNotNull);
    });

    test('**the guard**: the background service is held while any copy '
        'runs, and the notice goes with the last', () async {
      final pulls = box().read(devicePullsProvider.notifier);
      pulls.begin(PullKind.offline, 'a', 'One');
      pulls.begin(PullKind.share, 'b', 'Two');
      pulls.end(PullKind.offline, 'a');
      await Future<void>.delayed(Duration.zero);
      expect(held, [true], reason: 'the share would freeze');
      pulls.end(PullKind.share, 'b');
      await Future<void>.delayed(Duration.zero);
      expect(held, [true, false]);
      expect(notices.cancelled, contains(pullNoticeId));
    });

    test('**the guard**: many reports a second post the notice once, or '
        'Android drops them all', () async {
      final pulls = box().read(devicePullsProvider.notifier);
      pulls.begin(PullKind.offline, 'a', 'One', total: 100);
      // Four reports a quarter second apart, each past the screens' own
      // limit and each changing the share done.
      for (var i = 1; i <= 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        pulls.report(PullKind.offline, 'a', i * 10, 100);
      }
      await Future<void>.delayed(Duration.zero);
      expect(notices.progress.length, lessThanOrEqualTo(2));
    });

    test('**the guard**: the notice says how far it has got', () async {
      final pulls = box().read(devicePullsProvider.notifier);
      pulls.begin(PullKind.offline, 'a', 'One', total: 100);
      // Past the once-a-second limit, so the share done is posted.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      pulls.report(PullKind.offline, 'a', 45, 100);
      await Future<void>.delayed(Duration.zero);
      expect(notices.progress.last, ('Saving to device…', 45));
    });
  });

  group('available offline', () {
    test('**the guard**: asking twice copies the clip once', () async {
      final c = box();
      final actions = c.read(libraryActionsProvider);
      pull.gates['talk.mp4'] = Completer();
      final first = actions.makeOffline(_clip);
      final second = actions.makeOffline(_clip);
      await untilAsked(1);
      pull.gates['talk.mp4']!.complete();
      expect(await first, await second);

      expect(pull.asked, hasLength(1), reason: 'a second file was left over');
    });

    test('**the guard**: an offline copy can be stopped, and leaves '
        'nothing indexed', () async {
      final c = box();
      pull.gates['talk.mp4'] = Completer();
      final copy = c.read(libraryActionsProvider).makeOffline(_clip);
      await untilAsked(1);
      c
          .read(devicePullsProvider.notifier)
          .cancel(PullKind.offline, _clip.canonicalUrl);
      pull.gates['talk.mp4']!.complete();
      await expectLater(copy, throwsA(isA<CancelledException>()));
      expect(await c.read(offlineIndexProvider).readAll(), isEmpty);

      expect(c.read(devicePullsProvider), isEmpty);
    });

    test('**the guard**: a phone with no room says so before a byte '
        'is downloaded', () async {
      free = 50 * _mb;
      final c = box();
      await expectLater(
        c.read(libraryActionsProvider).makeOffline(_clip),
        throwsA(isA<NotEnoughSpaceException>()),
      );
      expect(pull.asked, isEmpty);
    });

    test('an unknown size, or a phone that does not answer, is let '
        'through', () async {
      final c = box();
      free = 1;
      await c.read(freeBytesProvider)('x');
      await expectLater(
        ensureRoomFor(c, null),
        completes,
        reason: 'guessing would block a copy that fits',
      );
      free = null;
      await expectLater(ensureRoomFor(c, 100 * _mb), completes);
    });
  });

  group('sharing a clip being saved', () {
    test('**the guard**: the share uses the offline copy instead of '
        'downloading a second one', () async {
      final c = box();
      pull.gates['talk.mp4'] = Completer();
      final copy = c.read(libraryActionsProvider).makeOffline(_clip);
      await untilAsked(1);
      final share = c.read(shareFlowProvider.notifier).start(_clip);
      pull.gates['talk.mp4']!.complete();
      await copy;
      await share;

      expect(pull.asked, hasLength(1));
      expect(sent.single, startsWith('${dir.path}/media'));
    });

    test('**the guard**: stopping that share leaves the offline copy '
        'running', () async {
      final c = box();
      pull.gates['talk.mp4'] = Completer();
      final copy = c.read(libraryActionsProvider).makeOffline(_clip);
      await untilAsked(1);
      final share = c.read(shareFlowProvider.notifier).start(_clip);
      await Future<void>.delayed(Duration.zero);
      c.read(shareFlowProvider.notifier).cancel();
      expect(pull.cancels['talk.mp4']!.isCancelled, isFalse);
      pull.gates['talk.mp4']!.complete();
      await copy;
      await share;

      expect(sent, isEmpty);
      expect(c.read(shareFlowProvider), isNull);
    });
  });

  testWidgets('the room message names both sizes', (tester) async {
    final l10n = await MTLocalizations.delegate.load(const Locale('ar'));
    final text = errorText(
      l10n,
      const NotEnoughSpaceException(needed: 3000 * _mb, free: 1200 * _mb),
    );
    expect(text, contains('2.9 GB'));
    expect(text, contains('1.2 GB'));
  });

  group('on screen', () {
    Widget app(Widget home, {List<Override> more = const []}) => ProviderScope(
      overrides: [...overrides(), ...more],
      child: MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

    testWidgets('**the guard**: the downloads screen part stops an offline '
        'copy', (tester) async {
      final pulls = {
        DevicePull.keyOf(PullKind.offline, 'u'): const DevicePull(
          kind: PullKind.offline,
          url: 'u',
          title: 'Saved clip',
          received: 20 * _mb,
          total: 80 * _mb,
        ),
      };
      late ProviderContainer c;
      await tester.pumpWidget(
        app(
          Consumer(
            builder: (context, ref, _) {
              c = ProviderScope.containerOf(context);
              return PhonePullsSection(pulls: pulls.values.toList());
            },
          ),
        ),
      );
      expect(find.text('To this phone'), findsOneWidget);
      expect(find.text('Saved clip'), findsOneWidget);
      expect(find.textContaining('25%'), findsOneWidget);
      final cancel = c
          .read(devicePullsProvider.notifier)
          .begin(PullKind.offline, 'u', 'Saved clip')!;
      await tester.tap(find.byTooltip('Cancel'));
      expect(cancel.isCancelled, isTrue);
    });

    testWidgets('**the guard**: a share sheet left under another sheet goes '
        'when the share is done', (tester) async {
      await tester.pumpWidget(
        app(
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => shareClip(context, ref, _clip),
              child: const Text('share'),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        pull.gates['talk.mp4'] = Completer();
        await tester.tap(find.text('share'));
        await untilAsked(1);
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShareSheet), findsOneWidget);
      final context = tester.element(find.byType(ShareSheet));
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          builder: (_) => const Text('another sheet'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        pull.gates['talk.mp4']!.complete();
        // Until the share menu opens, however busy the machine is.
        while (sent.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('another sheet'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ShareSheet), findsNothing);
    });

    testWidgets('**the guard**: past 2 GB the question says which apps will '
        'not take the file', (tester) async {
      await tester.pumpWidget(
        app(
          Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => shareClip(
                context,
                ref,
                const LibraryItem(
                  canonicalUrl: 'https://youtu.be/huge',
                  title: 'Huge',
                  serverFilename: 'huge.mp4',
                  sizeBytes: 3 * shareMessagingBytes,
                ),
              ),
              child: const Text('share'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('share'));
      await tester.pumpAndSettle();
      expect(find.textContaining('WhatsApp'), findsOneWidget);
    });

    testWidgets('every phone and text size', (tester) async {
      await expectNoOverflow(
        tester,
        () => app(
          SingleChildScrollView(
            child: PhonePullsSection(
              pulls: [
                DevicePull(
                  kind: PullKind.share,
                  url: 'a',
                  title: 'B' * 200,
                  received: 1500 * _mb,
                  total: 3000 * _mb,
                  rate: 12.5 * _mb,
                ),
                // A size, so the bar is still and the frames settle.
                const DevicePull(
                  kind: PullKind.offline,
                  url: 'c',
                  title: 'Short',
                  total: 10,
                ),
              ],
            ),
          ),
        ),
      );
    });
  });
}

/// The room check, reached through a provider read as the app does it.
Future<void> ensureRoomFor(ProviderContainer c, int? size) =>
    c.read(_roomProbe)(size);

final _roomProbe = Provider<Future<void> Function(int? size)>(
  (ref) =>
      (size) => ensureRoom(ref, '/tmp', size),
);
