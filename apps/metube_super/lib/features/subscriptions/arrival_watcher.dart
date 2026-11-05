import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../home/download_watcher.dart' show notificationsProvider;
import 'subscriptions_providers.dart';

/// **What has already been accounted for**: the canonical URLs of every
/// completed item on the server the last time `/history` was read.
///
/// A set of keys and not a timestamp, because MeTube stamps an item when it
/// is **created** and never again (`ytdl.py:506`), while an arrival is an
/// item **finishing**. A subscription clip queued before a manual one and
/// finished after it sits below any timestamp watermark and was skipped.
const arrivalSeenKey = 'subs_seen_keys';

/// The timestamp watermark this replaced (2.2.0 test builds only), read
/// once to carry its answer over and then removed.
const arrivalWatermarkKey = 'subs_seen_timestamp';

/// What this phone sent and the server has not finished yet, kept across
/// runs: [UnfinishedSends].
const arrivalUnfinishedKey = 'subs_unfinished_sends';

/// What each subscription's checks queued: [SubscriptionChecks].
const arrivalChecksKey = 'subs_checks';

/// A fixed id, so a second batch replaces the first notice instead of
/// stacking a second one beside it.
const arrivalNotificationId = 770001;

/// **Telling the user when the server brought something by itself**
/// (subscription arrivals).
///
/// A subscription download has no task here: MeTube fetches it and the
/// clip turns up in `/history`, with nothing else saying so.
///
/// **What counts**: a completed item not yet accounted for, that this app
/// did not send (the engine announces those), and that a subscription's
/// check queued ([SubscriptionChecks]); a clip another device or the web
/// page sent is nobody's news here.
///
/// **It cannot wake the app up**, by choice (a background poll costs
/// battery): it runs whenever `/history` is read, so the notice arrives
/// with the user.
class ArrivalWatcher {
  ArrivalWatcher(this._ref);

  final Ref _ref;

  /// Canonical URLs this app asked for during this run. The engine
  /// announces these itself.
  final Set<String> _mine = {};

  /// Null until the stored set has been read once, and null after that
  /// on a first run, which is what keeps a first run silent.
  Set<String>? _seen;
  bool _loaded = false;
  bool _busy = false;

  /// Whether the last pass found no list and left its arrivals unseen.
  bool _askedAgain = false;

  void noteOwnTask(String? canonicalUrl) {
    if (canonicalUrl != null && canonicalUrl.isNotEmpty) {
      if (_mine.add(canonicalUrl)) unawaited(_keep(canonicalUrl));
    }
  }

  UnfinishedSends get _sends => _unfinished ??= UnfinishedSends(
    store: _ref.read(keyValueStoreProvider),
    mutex: _ref.read(prefsMutexProvider),
    key: arrivalUnfinishedKey,
  );
  UnfinishedSends? _unfinished;

  SubscriptionChecks get _checks => _checksStore ??= SubscriptionChecks(
    store: _ref.read(keyValueStoreProvider),
    mutex: _ref.read(prefsMutexProvider),
    key: arrivalChecksKey,
  );
  SubscriptionChecks? _checksStore;

  Future<void> _keep(String canonicalUrl) async {
    try {
      await _sends.note(
        canonicalUrl,
        finished: _seen?.contains(canonicalUrl) ?? false,
      );
    } on Object {
      // Only one notice too many if the app closes before this clip ends.
    }
  }

  Future<void> onHistory(HistoryResponse history) async {
    // One pass at a time: `/history` can be re-read every two seconds
    // during a download, and two passes would both read the old set and
    // notify twice for the same clips.
    if (_busy) return;
    _busy = true;
    try {
      await _process(history);
    } on Object {
      // A notice nobody can post is not worth breaking the library over.
    } finally {
      _busy = false;
    }
  }

  Future<void> _process(HistoryResponse history) async {
    final done = history.done.where((item) => item.isCompleted).toList();
    if (done.isEmpty) return;
    final now = {for (final item in done) item.canonicalUrl};

    final store = _ref.read(keyValueStoreProvider);
    if (!_loaded) {
      _seen = await _load(store, done);
      _mine.addAll(await _sends.all());
      _loaded = true;
      await _observeChecks();
    }
    final seen = _seen;
    await _sends.settle(now);

    // **The first run announces nothing.** A fresh install, or a phone
    // restored from a backup, would otherwise report the server's entire
    // library as having just arrived. **Nor does another server**: Super
    // switches servers, and a library with not one key in common is a
    // different library, not a thousand arrivals. The same server reached
    // by its tunnel address shares every key, so it is not mistaken.
    if (seen == null || (seen.isNotEmpty && !now.any(seen.contains))) {
      await _save(store, now);
      return;
    }

    final arrivals = [
      for (final item in done)
        if (!seen.contains(item.canonicalUrl) &&
            !_mine.contains(item.canonicalUrl))
          item,
    ];
    if (arrivals.isEmpty) {
      // Only what left: keep the set to what the server holds, so a clip
      // deleted and fetched again is news again. Unchanged, no write —
      // this runs every two seconds during a download.
      if (seen.length != now.length || !seen.containsAll(now)) {
        await _save(store, now);
      }
      return;
    }

    if (_ref.read(settingsProvider).notifyArrivals) {
      // **Read afresh and awaited**: each subscription's count and last
      // check tell a clip it queued from one sent elsewhere, and a list
      // still loading on a fresh start once read as "none" and swallowed
      // the first batch (2026-09-23).
      _ref.invalidate(subscriptionsProvider);
      final subs = await _ref.read(subscriptionsProvider.future);
      // **No answer is asked twice before it counts as "none".** The client
      // reads a failed request and a MeTube without subscriptions alike,
      // as no list. A blip at start-up would otherwise stay cached for the
      // whole run and swallow every arrival in it; an old server costs one
      // extra request per batch.
      if (!subs.supported && !_askedAgain) {
        _askedAgain = true;
        _ref.invalidate(subscriptionsProvider);
        return;
      }
      _askedAgain = false;
      if (subs.sorted.any((sub) => sub.enabled)) {
        final sorted = await sortArrivals<HistoryItem>(
          arrivals,
          urlOf: (item) => item.canonicalUrl,
          uploaderOf: (item) => item.uploader,
          following: subs.sorted,
          author: _ref.read(arrivalAuthorProvider),
        );
        // **Only what a check queued** (owner's report, 2026-11-05): a clip
        // the computer, the web page or this phone in another run sent is
        // nobody's news, even from a channel that is followed.
        await _checks.observe(subs.sorted);
        final worth = await _checks.fromChecks([
          ...sorted.followed,
          ...sorted.unknown,
        ], createdOf: (item) => item.timestamp);
        // Marked seen first: a notice twice is worse than a notice lost to
        // a failed write.
        await _save(store, now);
        if (worth.isNotEmpty) await _announce(worth);
        return;
      }
    }
    // Switched off, or nothing followed: accounted for all the same, or
    // switching it back on would announce a backlog.
    await _save(store, now);
  }

  Future<Set<String>?> _load(
    KeyValueStore store,
    List<HistoryItem> done,
  ) async {
    final stored = await store.getStringList(arrivalSeenKey);
    if (stored != null) return stored.toSet();
    // A test build kept a timestamp: what it had passed is seen, and what
    // came after it is still news.
    final mark = await store.getInt(arrivalWatermarkKey);
    if (mark == null) return null;
    await _ref
        .read(prefsMutexProvider)
        .run(() => store.remove(arrivalWatermarkKey));
    return {
      for (final item in done)
        if ((item.timestamp?.millisecondsSinceEpoch ?? 0) <= mark)
          item.canonicalUrl,
    };
  }

  Future<void> _save(KeyValueStore store, Set<String> keys) async {
    _seen = keys;
    await _ref
        .read(prefsMutexProvider)
        .run(() => store.setStringList(arrivalSeenKey, keys.toList()));
  }

  /// Where counting starts for this run, so the first batch is weighed
  /// against the checks since the app was last open rather than since ever.
  Future<void> _observeChecks() async {
    if (!_ref.read(settingsProvider).notifyArrivals) return;
    try {
      final subs = await _ref.read(subscriptionsProvider.future);
      if (subs.supported) await _checks.observe(subs.sorted);
    } on Object {
      // The batch that needs it reads the list again.
    }
  }

  /// Clips a subscription's check queued, so the notice says so.
  Future<void> _announce(List<HistoryItem> arrivals) async {
    final l10n = mtLocalizationsFor(_ref.read(settingsProvider).localeCode);
    // **One notice for the batch**, as asked 2026-09-20: a channel checked
    // hourly can deliver several clips at once, and one line per clip
    // would be the reason the feature gets turned off.
    // A server record can carry no title at all; its URL is the only thing
    // it is guaranteed to have, and an empty notification body says less
    // than an ugly one.
    String nameOf(HistoryItem item) => (item.title?.trim().isNotEmpty ?? false)
        ? item.title!.trim()
        : item.canonicalUrl;
    final body = arrivals.length == 1
        ? nameOf(arrivals.first)
        : arrivals.take(3).map(nameOf).join(' · ');
    await _ref
        .read(notificationsProvider)
        .showResult(
          arrivalNotificationId,
          title: l10n.newFromSubscriptions(arrivals.length),
          body: body,
          channelName: l10n.subscriptions,
          // Tapping opens the app on the newest of them.
          payload: arrivals.first.canonicalUrl,
        );
    await _ref
        .read(loggerProvider)
        .log('subscription arrivals: ${arrivals.length}', tag: 'subs');
  }
}

/// Who posted an arrived clip, from its public address.
final arrivalAuthorProvider = Provider<ClipAuthorLookup>(
  (ref) => clipAuthorFrom(ClipPreviewResolver()),
);

/// The watcher itself, separate from the wiring below so a test can drive
/// it a history at a time instead of simulating the whole app.
final arrivalWatcherInstanceProvider = Provider<ArrivalWatcher>(
  ArrivalWatcher.new,
);

/// Kept alive from the shell, like the download watcher.
final arrivalWatcherProvider = Provider<void>((ref) {
  final watcher = ref.watch(arrivalWatcherInstanceProvider);

  // Everything the engine touches is ours, whatever state it is in.
  ref.listen<AsyncValue<List<DownloadTask>>>(engineTasksProvider, (_, next) {
    for (final task in next.valueOrNull ?? const <DownloadTask>[]) {
      watcher.noteOwnTask(task.canonicalUrl);
    }
  }, fireImmediately: true);

  ref.listen<AsyncValue<HistoryResponse?>>(historyProvider, (_, next) {
    final history = next.valueOrNull;
    if (history != null) unawaited(watcher.onHistory(history));
  }, fireImmediately: true);
});
