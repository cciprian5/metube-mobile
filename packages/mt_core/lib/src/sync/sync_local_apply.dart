part of 'sync_local.dart';

Future<bool> _apply(SyncLocal l, SyncSnapshot merged) => l.mutex.run(() async {
  var changed = false;
  Future<void> put(String key, String value) async {
    if (await l.store.getString(key) == value) return;
    await l.store.setString(key, value);
    changed = true;
  }

  final localTags = SyncLocal._decodeMap(
    await l.store.getString(SyncLocal._tags),
  );
  await put(
    SyncLocal._tags,
    jsonEncode({
      for (final MapEntry(key: url, value: pairs) in merged.tags.entries)
        if (SyncLocal._present(pairs, SyncLocal._strings(localTags[url]))
            case final on when on.isNotEmpty)
          url: on,
    }),
  );
  await put(
    TagsIndex.stampsKey,
    jsonEncode({
      for (final MapEntry(key: url, value: pairs) in merged.tags.entries)
        if (SyncLocal._timed(pairs) case final timed when timed.isNotEmpty)
          url: timed,
    }),
  );

  for (final MapEntry(key: url, value: s) in merged.positions.entries) {
    final now = await l.store.getInt('${SyncLocal._position}$url');
    if (s.removed && now != null) {
      await l.store.remove('${SyncLocal._position}$url');
      changed = true;
    } else if (!s.removed && now != s.value) {
      await l.store.setInt('${SyncLocal._position}$url', s.value!);
      changed = true;
    }
    if (s.at > 0 &&
        await l.store.getInt('${SyncLocal._positionStamp}$url') != s.at) {
      await l.store.setInt('${SyncLocal._positionStamp}$url', s.at);
    }
  }

  await _applyLists(l, merged, put);
  if (l.searchesKey case final key?) {
    await _applySearches(l, merged, key, put);
  }
  return changed;
});

Future<void> _applyLists(
  SyncLocal l,
  SyncSnapshot merged,
  Future<void> Function(String key, String value) put,
) async {
  final local = {for (final p in await l._lists()) p.id: p};
  final removals = PlaylistRemovals();
  final out = <SavedPlaylist>[];
  // The lists already here keep their place; new ones follow.
  final ids = [
    ...local.keys.where(merged.lists.containsKey),
    ...merged.lists.keys.where((id) => !local.containsKey(id)),
  ];
  for (final id in ids) {
    final s = merged.lists[id]!;
    if (s.removed) {
      removals.lists[id] = s.at;
      continue;
    }
    final members = merged.members[id] ?? const {};
    final here = [
      for (final key in s.value!.order)
        if (members[key] case final m? when !m.removed) key,
    ];
    final later = [
      for (final MapEntry(:key, :value) in members.entries)
        if (!value.removed && !here.contains(key)) key,
    ]..sort((a, b) => members[a]!.at.compareTo(members[b]!.at));
    final mine = local[id];
    out.add(
      SavedPlaylist(
        id: id,
        name: s.value!.name,
        pinned: s.value!.pinned,
        createdAt: s.value!.createdAt > 0
            ? DateTime.fromMillisecondsSinceEpoch(s.value!.createdAt)
            : mine?.createdAt,
        lastPlayedAt: mine?.lastPlayedAt,
        updatedAt: SyncLocal._date(s.at),
        items: [
          for (final key in [...here, ...later])
            PlaylistEntry(
              canonicalUrl: key,
              serverFilename: members[key]!.value!.serverFilename,
              cachedTitle: members[key]!.value!.title,
              cachedThumb: members[key]!.value!.thumbnail,
              addedAt: SyncLocal._date(members[key]!.at),
            ),
          // Entries from the old Lite format have no clip address to
          // sync by; they stay as they are, here only.
          ...?mine?.items.where((e) => e.isLegacy),
        ],
      ),
    );
    for (final MapEntry(:key, :value) in members.entries) {
      if (value.removed) (removals.members[id] ??= {})[key] = value.at;
    }
  }
  await put(
    PlaylistsStore.prefsKey,
    jsonEncode([for (final p in out) p.toJson()]),
  );
  await put(PlaylistRemovals.prefsKey, removals.encode());
}

Future<void> _applySearches(
  SyncLocal l,
  SyncSnapshot merged,
  String key,
  Future<void> Function(String key, String value) put,
) async {
  final local = [
    for (final item in SyncLocal._decodeList(await l.store.getString(key)))
      if (item is Map) '${item['id']}',
  ];
  final ids = [
    ...local.where(merged.searches.containsKey),
    ...merged.searches.keys.where((id) => !local.contains(id)),
  ];
  await put(
    key,
    jsonEncode([
      for (final id in ids)
        if (merged.searches[id] case final s? when !s.removed)
          {
            'id': id,
            'name': s.value!.name,
            'query': s.value!.query,
            'at': s.at,
          },
    ]),
  );
  await put(
    l._searchesRemoved,
    jsonEncode({
      for (final MapEntry(key: id, value: s) in merged.searches.entries)
        if (s.removed) id: s.at,
    }),
  );
}
