import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

/// The owner's report, 2026-11-05: a clip downloaded from the phone was
/// announced on the computer as news from a subscription, and the other way
/// round. A clip came from a subscription only when a check whose count
/// rose could have queued it.
void main() {
  final t0 = DateTime(2026, 11, 5, 12);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  ChannelSubscription sub(String id, {required int seen, required int at}) =>
      ChannelSubscription(
        id: id,
        name: id,
        url: 'https://www.youtube.com/@$id',
        enabled: true,
        checkIntervalMinutes: 60,
        seenCount: seen,
        lastChecked: t0.add(Duration(minutes: at)),
      );

  late MemoryKeyValueStore store;
  late SubscriptionChecks checks;
  setUp(() {
    store = MemoryKeyValueStore();
    checks = SubscriptionChecks(
      store: store,
      mutex: PrefsMutex(),
      key: 'checks',
      clock: () => at(90),
    );
  });

  Future<List<DateTime>> taken(List<DateTime> created) =>
      checks.fromChecks(created, createdOf: (d) => d);

  test('**the guard**: a clip added by hand, while no check queued '
      'anything, is not from a subscription', () async {
    await checks.observe([sub('a', seen: 10, at: 0)]);
    // The next check found nothing new.
    await checks.observe([sub('a', seen: 10, at: 60)]);
    expect(await taken([at(30)]), isEmpty);
  });

  test('**the guard**: what a check queued is taken, and a clip added by '
      'hand meanwhile is not', () async {
    await checks.observe([sub('a', seen: 10, at: 0)]);
    // The check at 60 queued one clip (created just before it was stamped).
    await checks.observe([sub('a', seen: 11, at: 60)]);
    final queued = at(60).subtract(const Duration(milliseconds: 300));
    // A clip added by hand after that check.
    final byHand = at(70);
    expect(await taken([byHand, queued]), [queued]);
  });

  test('a check that queued one clip excuses one, even across looks', () async {
    await checks.observe([sub('a', seen: 10, at: 0)]);
    await checks.observe([sub('a', seen: 12, at: 60)]);
    expect(await taken([at(59)]), [at(59)]);
    // The second clip finishes later, and is still the check's.
    expect(await taken([at(58)]), [at(58)]);
    // A third has no credit left.
    expect(await taken([at(57)]), isEmpty);
  });

  test('in a wide window the clip made at the check wins over one added '
      'by hand earlier in it', () async {
    await checks.observe([sub('a', seen: 10, at: 0)]);
    // Looked at again only hours later: one rise for the whole stretch.
    await checks.observe([sub('a', seen: 11, at: 180)]);
    final byHand = at(40);
    final queued = at(180).subtract(const Duration(seconds: 5));
    expect(await taken([byHand, queued]), [queued]);
  });

  test('a new subscription queues nothing by being added', () async {
    // Subscribing marks the whole catalogue seen.
    await checks.observe([sub('b', seen: 214, at: 0)]);
    expect(await taken([at(-1)]), isEmpty);
  });

  test('credits expire with their clip unused', () async {
    await checks.observe([sub('a', seen: 10, at: 0)]);
    await checks.observe([sub('a', seen: 11, at: 60)]);
    final later = SubscriptionChecks(
      store: store,
      mutex: PrefsMutex(),
      key: 'checks',
      clock: () => at(90).add(const Duration(days: 4)),
    );
    await later.observe([sub('a', seen: 11, at: 60)]);
    expect(await later.fromChecks([at(59)], createdOf: (d) => d), isEmpty);
  });

  test('a damaged value starts counting again', () async {
    await store.setString('checks', 'not json');
    await checks.observe([sub('a', seen: 10, at: 0)]);
    expect(await taken([at(-5)]), isEmpty);
  });
}
