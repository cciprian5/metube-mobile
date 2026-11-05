import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/library_watch.dart';
import 'package:mt_core/mt_core.dart';

import 'support/shell_harness.dart';

HistoryResponse _history(List<String> titles, {List<String> queue = const []}) {
  Map<String, Object> item(String t, String status) => {
    'id': t,
    'url': 'https://youtu.be/${t.hashCode}',
    'title': t,
    'filename': '$t.mp4',
    'status': status,
  };
  return HistoryResponse.fromJson({
    'done': [for (final t in titles) item(t, 'finished')],
    'queue': [for (final t in queue) item(t, 'downloading')],
    'pending': <Object>[],
  });
}

/// The library keeps up with the server by itself: a clip sent from the
/// phone shows without a button, and the server is asked only as often as
/// the moment needs.
void main() {
  Future<ShellHarness> open(WidgetTester tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    final h = ShellHarness(server: ServerConfig(baseUrl: 'http://nas:8081'));
    h.api.history = _history(['Blue Hour']);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('**the guard**: a clip the phone sent shows by itself, '
      'with one request for the change', (tester) async {
    final h = await open(tester);
    expect(find.text('Blue Hour'), findsWidgets);
    expect(find.text('Sent From The Phone'), findsNothing);

    h.api.history = _history(['Sent From The Phone', 'Blue Hour']);
    final asked = h.api.historyAsked;
    await tester.pump(libraryWatchIdle + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Sent From The Phone'), findsWidgets);
    // The watcher's own list is handed over, not fetched a second time.
    expect(h.api.historyAsked, asked + 1);
  });

  testWidgets('while the server downloads, it is asked every few seconds', (
    tester,
  ) async {
    final h = await open(tester);
    h.api.history = _history(['Blue Hour'], queue: ['On Its Way']);
    await tester.pump(libraryWatchIdle + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    h.api.history = _history(['On Its Way', 'Blue Hour']);
    await tester.pump(libraryWatchBusy + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('On Its Way'), findsWidgets);
  });

  testWidgets('coming back to the window asks at once', (tester) async {
    final h = await open(tester);
    await tester.pump(libraryWatchMinGap + const Duration(seconds: 1));
    final asked = h.api.historyAsked;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(h.api.historyAsked, asked + 1);
    await tester.pumpAndSettle();
  });

  test('home addresses are asked often, outside ones less', () {
    for (final near in [
      'http://192.168.1.10:8081',
      'http://10.0.0.5',
      'http://172.20.1.1',
      'http://nas:8081',
      'http://nas.local',
      'http://localhost:8081',
    ]) {
      expect(isNearbyAddress(near), isTrue, reason: near);
    }
    for (final far in [
      'https://metube.example.com',
      'http://172.32.0.1',
      'https://8.8.8.8',
    ]) {
      expect(isNearbyAddress(far), isFalse, reason: far);
    }
    expect(
      libraryWatchEvery(shown: true, nearby: false, busy: false),
      greaterThan(libraryWatchEvery(shown: true, nearby: true, busy: false)),
    );
    expect(
      libraryWatchEvery(shown: false, nearby: true, busy: true),
      libraryWatchHidden,
    );
  });

  test('an unchanged list is not a change', () {
    expect(
      historyPrint(_history(['A', 'B'])),
      historyPrint(_history(['A', 'B'])),
    );
    expect(
      historyPrint(_history(['A', 'B'])),
      isNot(historyPrint(_history(['A']))),
    );
  });
}
