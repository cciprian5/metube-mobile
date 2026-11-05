import 'dart:convert';

/// **When saved lists, and members of them, were taken away**, so a merge
/// with another device does not bring them back: a list deleted here
/// leaves its id and time, a clip taken out of a list leaves the pair and
/// its time.
///
/// Kept beside `saved_playlists` under its own key, so the lists' format,
/// and every reader of it, stays as it was. Written only by an app that
/// stamps its edits; one that does not never creates the key.
class PlaylistRemovals {
  PlaylistRemovals({
    Map<String, int>? lists,
    Map<String, Map<String, int>>? members,
  }) : lists = lists ?? {},
       members = members ?? {};

  static const String prefsKey = 'saved_playlists_removed';

  /// By list id, in epoch milliseconds.
  final Map<String, int> lists;

  /// By list id, then member key.
  final Map<String, Map<String, int>> members;

  bool get isEmpty => lists.isEmpty && members.isEmpty;

  static PlaylistRemovals decode(String? raw) {
    if (raw == null || raw.isEmpty) return PlaylistRemovals();
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return PlaylistRemovals();
    }
    if (json is! Map) return PlaylistRemovals();
    return PlaylistRemovals(
      lists: {
        if (json['lists'] case final Map lists)
          for (final MapEntry(:key, :value) in lists.entries)
            if (value is int) '$key': value,
      },
      members: {
        if (json['members'] case final Map members)
          for (final MapEntry(:key, :value) in members.entries)
            if (value is Map)
              '$key': {
                for (final MapEntry(key: member, value: ms) in value.entries)
                  if (ms is int) '$member': ms,
              },
      },
    );
  }

  String encode() => jsonEncode({'lists': lists, 'members': members});

  /// Records what an edit took away at [now] and clears what it put back:
  /// [before] and [after] are each list's member keys, by id.
  ///
  /// A deleted list drops its members' records with it: the list's own
  /// record already says all of them went.
  bool record(
    Map<String, Set<String>> before,
    Map<String, Set<String>> after,
    int now,
  ) {
    var changed = false;
    for (final id in before.keys) {
      final has = after[id];
      if (has == null) {
        lists[id] = now;
        members.remove(id);
        changed = true;
        continue;
      }
      for (final key in before[id]!.difference(has)) {
        (members[id] ??= {})[key] = now;
        changed = true;
      }
    }
    for (final MapEntry(key: id, value: has) in after.entries) {
      if (lists.remove(id) != null) changed = true;
      final gone = members[id];
      if (gone == null) continue;
      for (final key in has.difference(before[id] ?? const {})) {
        if (gone.remove(key) != null) changed = true;
      }
      if (gone.isEmpty) members.remove(id);
    }
    return changed;
  }

  /// Forgets the records older than [cutoff] (epoch ms); true when any
  /// went.
  bool forgetBefore(int cutoff) {
    final count = lists.length + members.values.fold(0, (n, m) => n + m.length);
    lists.removeWhere((_, at) => at < cutoff);
    for (final gone in members.values) {
      gone.removeWhere((_, at) => at < cutoff);
    }
    members.removeWhere((_, gone) => gone.isEmpty);
    return count !=
        lists.length + members.values.fold(0, (n, m) => n + m.length);
  }
}
