import 'dart:convert';

import 'sync_snapshot.dart';

/// What a device holds after reading the others.
class SyncOutcome {
  const SyncOutcome(this.snapshot, {this.cameBack = false});

  final SyncSnapshot snapshot;

  /// The device was away longer than [SyncMerge.keepRemovals], so what it
  /// held from before was set aside and the other devices' data taken; the
  /// app says so once.
  final bool cameBack;
}

/// **The merge of the sync folder**, the same on every device:
///
/// - For each fact (a (clip, tag) pair, a position, a list, a (list, clip)
///   member, a saved search) **the later change wins**, a removal included,
///   so a merge never brings back what was deleted after it was written.
/// - **Commutative and idempotent**: a ⊕ b holds what b ⊕ a holds, and
///   merging again changes nothing, so devices that read each other in any
///   order end up the same.
/// - Removals are forgotten after [keepRemovals]; a device away longer than
///   that takes the others' data first ([forDevice]), or it would bring
///   back what was deleted while it was off.
abstract final class SyncMerge {
  static const keepRemovals = Duration(days: 90);

  /// a ⊕ b, under [a]'s device name.
  static SyncSnapshot merge(SyncSnapshot a, SyncSnapshot b) => a.copyWith(
    writtenAt: a.writtenAt > b.writtenAt ? a.writtenAt : b.writtenAt,
    tags: _nested(a.tags, b.tags),
    positions: _flat(a.positions, b.positions),
    lists: _flat(a.lists, b.lists),
    members: _nested(a.members, b.members),
    searches: _flat(a.searches, b.searches),
  );

  /// The later of two versions of one fact. At the same moment a value
  /// beats a removal (only unstamped data, both at 0, meets this in
  /// practice, and keeping it loses nothing), and two values are ordered by
  /// their contents, so the choice never depends on which side is which.
  static Stamped<T> pick<T>(Stamped<T> x, Stamped<T> y) {
    if (x.at != y.at) return x.at > y.at ? x : y;
    if (x.removed != y.removed) return x.removed ? y : x;
    return jsonEncode(x.value).compareTo(jsonEncode(y.value)) >= 0 ? x : y;
  }

  /// [snapshot] without the removals older than [keepRemovals] at [now].
  static SyncSnapshot prune(SyncSnapshot snapshot, {required int now}) {
    final limit = now - keepRemovals.inMilliseconds;
    bool keep<T>(Stamped<T> s) => !s.removed || s.at >= limit;
    return _filtered(snapshot, keep);
  }

  /// This device's data after reading [others]: merged, removals past
  /// their time forgotten.
  ///
  /// **A file nobody has written for longer than [keepRemovals] is left
  /// out**: the removals made since it was written are forgotten by now,
  /// so it would bring back what was deleted. Every device writes its file
  /// at least daily while it runs ([heartbeat]), so only a device really
  /// gone goes quiet. A file without a time (written before files had one)
  /// is read as before.
  ///
  /// [lastSync] is when this device last merged successfully. Away longer
  /// than [keepRemovals], what it changed before leaving **and before the
  /// others' forgotten removals** is set aside: the others may have deleted
  /// it and since forgotten that they did, so it counts as theirs to say.
  /// Anything newer is kept, since a removal of it would still be in their
  /// files, and so is everything when no other device is there to say
  /// anything.
  static SyncOutcome forDevice({
    required SyncSnapshot mine,
    required Iterable<SyncSnapshot> others,
    required int now,
    int? lastSync,
  }) {
    final keep = keepRemovals.inMilliseconds;
    final live = [
      for (final other in others)
        if (other.deviceId != mine.deviceId &&
            (other.writtenAt <= 0 || now - other.writtenAt <= keep))
          other,
    ];
    final newest = live.fold(0, (at, o) => o.writtenAt > at ? o.writtenAt : at);
    final forgotten = (newest > 0 ? newest : now) - keep;
    final away = lastSync != null && now - lastSync > keep && live.isNotEmpty;
    var merged = away
        ? _filtered(
            mine,
            <T>(Stamped<T> s) => s.at > lastSync || s.at >= forgotten,
          )
        : mine;
    for (final other in live) {
      merged = merge(merged, other);
    }
    return SyncOutcome(prune(merged, now: now), cameBack: away);
  }

  /// How stale this device's own file may get before it is written again
  /// though nothing changed, so the others do not take it for gone.
  static const heartbeat = Duration(days: 1);

  static Map<String, Stamped<T>> _flat<T>(
    Map<String, Stamped<T>> a,
    Map<String, Stamped<T>> b,
  ) => {
    for (final key in _keys(a, b))
      key: switch ((a[key], b[key])) {
        (final x?, final y?) => pick(x, y),
        (final x?, null) => x,
        (null, final y?) => y,
        (null, null) => throw StateError('unreachable'),
      },
  };

  static Map<String, Map<String, Stamped<T>>> _nested<T>(
    Map<String, Map<String, Stamped<T>>> a,
    Map<String, Map<String, Stamped<T>>> b,
  ) => {
    for (final key in _keys(a, b))
      key: _flat(a[key] ?? const {}, b[key] ?? const {}),
  };

  /// Sorted, so a merge reads the same whichever side came first.
  static List<String> _keys(Map<String, Object?> a, Map<String, Object?> b) =>
      {...a.keys, ...b.keys}.toList()..sort();

  static SyncSnapshot _filtered(
    SyncSnapshot s,
    bool Function<T>(Stamped<T> entry) keep,
  ) {
    Map<String, Stamped<T>> flat<T>(Map<String, Stamped<T>> map) => {
      for (final MapEntry(:key, :value) in map.entries)
        if (keep(value)) key: value,
    };
    Map<String, Map<String, Stamped<T>>> nested<T>(
      Map<String, Map<String, Stamped<T>>> map,
    ) => {
      for (final MapEntry(:key, :value) in map.entries)
        if (flat(value) case final inner when inner.isNotEmpty) key: inner,
    };
    return s.copyWith(
      tags: nested(s.tags),
      positions: flat(s.positions),
      lists: flat(s.lists),
      members: nested(s.members),
      searches: flat(s.searches),
    );
  }
}
