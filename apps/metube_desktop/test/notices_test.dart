import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/notices.dart';
import 'package:metube_desktop/di.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

/// Windows' notifications, recording what they were asked to show.
class _Notices implements NoticePort {
  final shown = <EmberNotice>[];

  @override
  Future<void> show(EmberNotice notice) async => shown.add(notice);
}

LibraryItem _onServer(String id, {int day = 1}) => LibraryItem(
  canonicalUrl: 'https://youtu.be/$id',
  title: id,
  onServer: true,
  serverFilename: '$id.mp4',
  timestamp: DateTime(2026, 10, day),
);

void main() {
  group('what arrived by itself', () {
    late ProviderContainer container;
    late MemoryKeyValueStore store;

    setUp(() {
      store = MemoryKeyValueStore();
      container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
    });

    test('**the guard**: the first run says nothing; then only what is new '
        'and not sent from here, newest first', () async {
      final arrivals = container.read(arrivalsProvider);
      final library = [_onServer('a'), _onServer('b')];
      expect(await arrivals.check(library, mine: {}), isEmpty);

      final later = [
        ...library,
        _onServer('c', day: 3),
        _onServer('d', day: 5),
        _onServer('mine', day: 6),
      ];
      final arrived = await arrivals.check(
        later,
        mine: {'https://youtu.be/mine'},
      );
      expect([for (final i in arrived) i.title], ['d', 'c']);
      // Said once: the next look finds nothing new.
      expect(await arrivals.check(later, mine: {}), isEmpty);
      expect(await store.getStringList(Arrivals.key), hasLength(5));
    });

    test('**the guard**: another server is another library, not a thousand '
        'arrivals', () async {
      final arrivals = container.read(arrivalsProvider);
      await arrivals.check([_onServer('a')], mine: {});
      final other = [for (var i = 0; i < 50; i++) _onServer('other$i')];
      expect(await arrivals.check(other, mine: {}), isEmpty);
    });
  });

  group('downloads', () {
    Future<(ShellHarness, _Notices)> open(
      WidgetTester tester, {
      bool inFront = false,
    }) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      final notices = _Notices();
      final h = ShellHarness(
        library: const [],
        server: ServerConfig(baseUrl: 'http://nas:8081'),
        overrides: [
          noticePortProvider.overrideWithValue(notices),
          windowInFrontProvider.overrideWithValue(() async => inFront),
        ],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      return (h, notices);
    }

    testWidgets('**the guard**: a download done away from the window is '
        'announced with its title and Play; a failure says why', (
      tester,
    ) async {
      final (h, notices) = await open(tester);
      final done = h.engine.submit(
        'https://youtu.be/aaaaaaaaaaa',
        Quality.best,
      );
      final broken = h.engine.submit(
        'https://youtu.be/bbbbbbbbbbb',
        Quality.best,
      );
      await tester.pumpAndSettle();
      expect(notices.shown, isEmpty);

      h.engine.finish(
        done.copyWith(
          title: 'Night Drive',
          canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
        ),
      );
      h.engine.fail(
        broken.copyWith(title: 'Blue Hour'),
        const AuthFailureException(),
      );
      await tester.pumpAndSettle();
      final [ok, failed] = notices.shown;
      expect((ok.title, ok.body), ('Download complete', 'Night Drive'));
      expect([for (final a in ok.actions) a.label], ['Play']);
      expect(failed.title, 'Download failed');
      expect(failed.body, startsWith('Blue Hour · '));
      expect(failed.body, isNot(endsWith('Failed')));
    });

    testWidgets('**the guard**: with the window in front, the panel says it '
        'and no notice is shown', (tester) async {
      final (h, notices) = await open(tester, inFront: true);
      final task = h.engine.submit(
        'https://youtu.be/aaaaaaaaaaa',
        Quality.best,
      );
      await tester.pumpAndSettle();
      h.engine.finish(task);
      await tester.pumpAndSettle();
      expect(notices.shown, isEmpty);
    });
  });
}
