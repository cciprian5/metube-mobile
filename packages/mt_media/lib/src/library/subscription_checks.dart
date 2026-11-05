import 'dart:convert';

import 'package:mt_core/mt_core.dart';

/// **Which arrivals a subscription check queued**, told from the checks
/// themselves.
///
/// `/history` says nothing of where a clip came from, so a clip another
/// device or MeTube's own page queued looks exactly like one a followed
/// channel brought, and the phone and the computer each announced what the
/// other had downloaded as news from a subscription.
///
/// MeTube's check queues what it found and only then records the check:
/// `last_checked` moves on and every queued clip joins `seen_ids`, whose
/// length is `seen_count`. So a clip came from a subscription only when it
/// was created inside a window that ended with a check whose count rose.
/// Each rise is a credit for that many clips created in its window; a clip
/// created outside every window (added by hand, from anywhere) has none.
///
/// A rise also counts clips the check filtered out by title, which never
/// arrive; their credit goes unused and expires after [keepFor].
class SubscriptionChecks {
  SubscriptionChecks({
    required this.store,
    required this.mutex,
    required this.key,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final KeyValueStore store;
  final PrefsMutex mutex;
  final String key;
  final DateTime Function() _clock;

  /// How long a credit waits for its clip: past any download's length.
  static const keepFor = Duration(days: 3);

  /// A check's time is stamped after its clips are created, on the same
  /// server clock; this covers rounding alone.
  static const _slack = Duration(seconds: 2);

  /// Records what each subscription's checks queued since the last look.
  /// A subscription seen for the first time only sets where counting
  /// starts: subscribing marks a whole catalogue seen and queues none of it.
  Future<void> observe(List<ChannelSubscription> subs) => mutex.run(() async {
    final state = await _read();
    final now = _clock();
    final counts = <String, _Count>{};
    for (final sub in subs) {
      final checked = sub.lastChecked;
      if (checked == null) continue;
      final before = state.counts[sub.id];
      counts[sub.id] = _Count(sub.seenCount, checked);
      if (before == null) continue;
      final rise = sub.seenCount - before.seen;
      if (rise > 0 && checked.isAfter(before.checked)) {
        state.credits.add(_Credit(before.checked, checked, rise, now));
      }
    }
    state.counts
      ..clear()
      ..addAll(counts);
    state.credits.removeWhere(
      (credit) => credit.left <= 0 || now.difference(credit.at) > keepFor,
    );
    await _write(state);
  });

  /// Of [arrivals], those a recorded check queued; each one taken spends
  /// its credit, so a check that queued one clip excuses one. Within a
  /// window the clips created nearest its end go first: a check creates
  /// its clips moments before it is stamped, while a clip added by hand
  /// falls anywhere in it. A clip with no creation time is not taken.
  Future<List<T>> fromChecks<T>(
    List<T> arrivals, {
    required DateTime? Function(T) createdOf,
  }) => mutex.run(() async {
    final state = await _read();
    final left = [
      for (final item in arrivals)
        if (createdOf(item) != null) item,
    ];
    final taken = <T>[];
    final credits = [...state.credits]..sort((a, b) => a.to.compareTo(b.to));
    for (final credit in credits) {
      final inside = [
        for (final item in left)
          if (createdOf(item)!.isAfter(credit.from) &&
              !createdOf(item)!.isAfter(credit.to.add(_slack)))
            item,
      ]..sort((a, b) => createdOf(b)!.compareTo(createdOf(a)!));
      for (final item in inside.take(credit.left)) {
        credit.left--;
        left.remove(item);
        taken.add(item);
      }
    }
    if (taken.isNotEmpty) await _write(state);
    return taken;
  });

  Future<_State> _read() async {
    final raw = await store.getString(key);
    if (raw == null) return _State({}, []);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final counts = <String, _Count>{
        for (final MapEntry(:key, :value)
            in (json['counts'] as Map<String, dynamic>? ?? const {}).entries)
          if (_Count.fromJson(value) case final count?) key: count,
      };
      final credits = [
        for (final row in json['credits'] as List? ?? const [])
          if (_Credit.fromJson(row) case final credit?) credit,
      ];
      return _State(counts, credits);
    } on Object {
      // A value from another version, or a damaged one: counting starts
      // again, which costs one batch its notice at most.
      return _State({}, []);
    }
  }

  Future<void> _write(_State state) => store.setString(
    key,
    jsonEncode({
      'counts': {
        for (final MapEntry(:key, :value) in state.counts.entries)
          key: value.toJson(),
      },
      'credits': [for (final credit in state.credits) credit.toJson()],
    }),
  );
}

class _State {
  _State(this.counts, this.credits);

  final Map<String, _Count> counts;
  final List<_Credit> credits;
}

/// A subscription's `seen_count` and `last_checked` at the last look.
class _Count {
  const _Count(this.seen, this.checked);

  final int seen;
  final DateTime checked;

  Map<String, Object> toJson() => {
    'seen': seen,
    'checked': checked.millisecondsSinceEpoch,
  };

  static _Count? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final seen = raw['seen'];
    final checked = raw['checked'];
    if (seen is! int || checked is! int) return null;
    return _Count(seen, DateTime.fromMillisecondsSinceEpoch(checked));
  }
}

/// Clips a check queued: [left] of them, created after [from] and by [to].
class _Credit {
  _Credit(this.from, this.to, this.left, this.at);

  final DateTime from;
  final DateTime to;
  int left;

  /// When it was recorded, for [SubscriptionChecks.keepFor].
  final DateTime at;

  Map<String, Object> toJson() => {
    'from': from.millisecondsSinceEpoch,
    'to': to.millisecondsSinceEpoch,
    'left': left,
    'at': at.millisecondsSinceEpoch,
  };

  static _Credit? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final values = [raw['from'], raw['to'], raw['left'], raw['at']];
    if (values.any((v) => v is! int)) return null;
    final [from, to, left, at] = values.cast<int>();
    return _Credit(
      DateTime.fromMillisecondsSinceEpoch(from),
      DateTime.fromMillisecondsSinceEpoch(to),
      left,
      DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}
