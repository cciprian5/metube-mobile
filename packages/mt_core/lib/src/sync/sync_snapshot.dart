import 'dart:convert';

/// One synced fact and when it last changed: a value that is there, or a
/// removal ([removed]) that must beat any older value from another device.
///
/// [at] is in epoch milliseconds; 0 means "written before stamping", the
/// oldest possible time.
class Stamped<T> {
  const Stamped(this.value, this.at) : removed = false;

  const Stamped.removed(this.at) : value = null, removed = true;

  final T? value;
  final int at;
  final bool removed;

  @override
  bool operator ==(Object other) =>
      other is Stamped<T> &&
      other.at == at &&
      other.removed == removed &&
      jsonEncode(other.value) == jsonEncode(value);

  @override
  int get hashCode => Object.hash(at, removed, jsonEncode(value));

  @override
  String toString() => removed ? 'removed@$at' : '$value@$at';
}

/// A saved list's own fields, apart from who is in it.
class SyncList {
  const SyncList({
    required this.name,
    this.pinned = false,
    this.createdAt = 0,
    this.order = const [],
  });

  final String name;
  final bool pinned;
  final int createdAt;

  /// The members' keys in the list's order; members missing from it go
  /// after, by when they joined.
  final List<String> order;

  Map<String, Object?> toJson() => {
    'name': name,
    'pinned': pinned,
    'createdAt': createdAt,
    'order': order,
  };

  static SyncList? fromJson(Object? json) => json is Map
      ? SyncList(
          name: '${json['name'] ?? ''}',
          pinned: json['pinned'] == true,
          createdAt: _int(json['createdAt']) ?? 0,
          order: [
            if (json['order'] case final List order)
              for (final key in order) '$key',
          ],
        )
      : null;
}

/// What a list keeps about one member besides its key, so a device that
/// has never seen the clip can still show it.
class SyncMember {
  const SyncMember({this.title, this.thumbnail, this.serverFilename});

  final String? title;
  final String? thumbnail;
  final String? serverFilename;

  Map<String, Object?> toJson() => {
    'title': ?title,
    'thumbnail': ?thumbnail,
    'serverFilename': ?serverFilename,
  };

  static SyncMember fromJson(Object? json) => json is Map
      ? SyncMember(
          title: json['title']?.toString(),
          thumbnail: json['thumbnail']?.toString(),
          serverFilename: json['serverFilename']?.toString(),
        )
      : const SyncMember();
}

/// A saved search: its name and the query it runs.
class SyncSearch {
  const SyncSearch({required this.name, required this.query});

  final String name;
  final String query;

  Map<String, Object?> toJson() => {'name': name, 'query': query};

  static SyncSearch? fromJson(Object? json) => json is Map
      ? SyncSearch(
          name: '${json['name'] ?? ''}',
          query: '${json['query'] ?? ''}',
        )
      : null;
}

/// **One device's file in the sync folder** (`<device>/library.json`):
/// everything it shares, each fact with its own time.
///
/// Tags and list members are kept **per pair**, (clip, tag) and (list,
/// clip), so a tag added on each of two devices survives a merge instead of
/// the newer clip overwriting the older whole. The favourite is the
/// favourites tag, so it travels as one more pair.
///
/// Read tolerantly: an unknown field is skipped, one bad entry is dropped
/// alone, and a file of a newer format is read for what this version
/// understands.
class SyncSnapshot {
  const SyncSnapshot({
    required this.deviceId,
    required this.deviceKind,
    this.appVersion = '',
    this.writtenAt = 0,
    this.tags = const {},
    this.positions = const {},
    this.lists = const {},
    this.members = const {},
    this.searches = const {},
  });

  /// The format this version writes. A file with a higher number is still
  /// read, for the fields named here.
  static const format = 1;

  final String deviceId;

  /// `phone` or `ember`, readable in the folder's name.
  final String deviceKind;
  final String appVersion;
  final int writtenAt;

  /// By clip, then tag.
  final Map<String, Map<String, Stamped<bool>>> tags;

  /// By clip: the position in milliseconds, removed when finished.
  final Map<String, Stamped<int>> positions;

  /// By list id.
  final Map<String, Stamped<SyncList>> lists;

  /// By list id, then member key (the clip's canonical URL).
  final Map<String, Map<String, Stamped<SyncMember>>> members;

  /// By saved search id.
  final Map<String, Stamped<SyncSearch>> searches;

  SyncSnapshot copyWith({
    String? deviceId,
    String? deviceKind,
    String? appVersion,
    int? writtenAt,
    Map<String, Map<String, Stamped<bool>>>? tags,
    Map<String, Stamped<int>>? positions,
    Map<String, Stamped<SyncList>>? lists,
    Map<String, Map<String, Stamped<SyncMember>>>? members,
    Map<String, Stamped<SyncSearch>>? searches,
  }) => SyncSnapshot(
    deviceId: deviceId ?? this.deviceId,
    deviceKind: deviceKind ?? this.deviceKind,
    appVersion: appVersion ?? this.appVersion,
    writtenAt: writtenAt ?? this.writtenAt,
    tags: tags ?? this.tags,
    positions: positions ?? this.positions,
    lists: lists ?? this.lists,
    members: members ?? this.members,
    searches: searches ?? this.searches,
  );

  String encode() => const JsonEncoder.withIndent(' ').convert({
    'format': format,
    'device': {'id': deviceId, 'kind': deviceKind, 'app': appVersion},
    'writtenAt': writtenAt,
    'tags': _nested(tags, (v) => v),
    'positions': _flat(positions, (v) => v),
    'lists': _flat(lists, (v) => v.toJson()),
    'members': _nested(members, (v) => v.toJson()),
    'searches': _flat(searches, (v) => v.toJson()),
  });

  /// Whether [id] can be a device's name: letters, digits, `-` and `_`,
  /// as [SyncFolder.newDeviceId] makes them. The name becomes a folder in
  /// the sync folder, and the file is written by another device, so
  /// anything that could climb out of it (`..`, a separator) is refused.
  static bool isDeviceId(String id) => _deviceId.hasMatch(id);

  static final _deviceId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// The file's contents, or null when it is not a sync file at all.
  static SyncSnapshot? decode(String contents) {
    final Object? json;
    try {
      json = jsonDecode(contents);
    } on FormatException {
      return null;
    }
    if (json is! Map || json['device'] is! Map) return null;
    final device = json['device'] as Map;
    final id = device['id'];
    if (id is! String || !isDeviceId(id) || _int(json['format']) == null) {
      return null;
    }
    return SyncSnapshot(
      deviceId: id,
      deviceKind: '${device['kind'] ?? ''}',
      appVersion: '${device['app'] ?? ''}',
      writtenAt: _int(json['writtenAt']) ?? 0,
      tags: _readNested(json['tags'], (v) => v == true ? true : null),
      positions: _readFlat(json['positions'], _int),
      lists: _readFlat(json['lists'], SyncList.fromJson),
      members: _readNested(json['members'], SyncMember.fromJson),
      searches: _readFlat(json['searches'], SyncSearch.fromJson),
    );
  }
}

int? _int(Object? value) => switch (value) {
  final int i => i,
  final double d when d == d.roundToDouble() => d.toInt(),
  _ => null,
};

Map<String, Object?> _entry<T>(Stamped<T> s, Object? Function(T) write) =>
    s.removed
    ? {'at': s.at, 'removed': true}
    : {'at': s.at, 'v': write(s.value as T)};

Map<String, Object?> _flat<T>(
  Map<String, Stamped<T>> map,
  Object? Function(T) write,
) => {
  for (final MapEntry(:key, :value) in map.entries) key: _entry(value, write),
};

Map<String, Object?> _nested<T>(
  Map<String, Map<String, Stamped<T>>> map,
  Object? Function(T) write,
) => {
  for (final MapEntry(:key, :value) in map.entries) key: _flat(value, write),
};

/// One stamped entry, or null when it cannot be read: a removal needs only
/// its time; a value needs a time and a value this version understands.
Stamped<T>? _readEntry<T>(Object? raw, T? Function(Object?) read) {
  if (raw is! Map) return null;
  final at = _int(raw['at']);
  if (at == null || at < 0) return null;
  if (raw['removed'] == true) return Stamped<T>.removed(at);
  final value = read(raw['v']);
  return value == null ? null : Stamped<T>(value, at);
}

Map<String, Stamped<T>> _readFlat<T>(Object? raw, T? Function(Object?) read) =>
    {
      if (raw is Map)
        for (final MapEntry(:key, :value) in raw.entries)
          '$key': ?_readEntry(value, read),
    };

Map<String, Map<String, Stamped<T>>> _readNested<T>(
  Object? raw,
  T? Function(Object?) read,
) => {
  if (raw is Map)
    for (final MapEntry(:key, :value) in raw.entries)
      if (_readFlat(value, read) case final inner when inner.isNotEmpty)
        '$key': inner,
};
