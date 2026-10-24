import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

const _a = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';

SyncSnapshot _full() => const SyncSnapshot(
  deviceId: 'ember-c3d4',
  deviceKind: 'ember',
  appVersion: '0.1.0',
  writtenAt: 1700000000000,
  tags: {
    _a: {
      'travel': Stamped(true, 10),
      'nature': Stamped.removed(20),
      MTConstants.favoritesSystemTag: Stamped(true, 30),
    },
  },
  positions: {
    _a: Stamped(65000, 40),
    'https://x.com/a/status/1': Stamped.removed(41),
  },
  lists: {
    'l1': Stamped(
      SyncList(name: 'مساء', pinned: true, createdAt: 5, order: [_a]),
      50,
    ),
    'l2': Stamped.removed(51),
  },
  members: {
    'l1': {
      _a: Stamped(
        SyncMember(title: 'رحلة السروات', serverFilename: 'a.mp4'),
        60,
      ),
      'https://youtu.be/gone': Stamped.removed(61),
    },
  },
  searches: {'s1': Stamped(SyncSearch(name: 'Pools', query: 'pool'), 70)},
);

void main() {
  test('a snapshot reads back exactly as written, removals included', () {
    final again = SyncSnapshot.decode(_full().encode())!;
    expect(again.encode(), _full().encode());
    expect(again.tags[_a]!['nature']!.removed, isTrue);
    expect(again.lists['l1']!.value!.name, 'مساء');
    expect(again.members['l1']!['https://youtu.be/gone']!.removed, isTrue);
  });

  test('**tolerant**: an unknown field, a newer format and one bad entry '
      'cost only themselves', () {
    final json = jsonDecode(_full().encode()) as Map<String, Object?>;
    json['format'] = 7;
    json['somethingNew'] = {'x': 1};
    (json['tags'] as Map)[_a] = {
      ...((json['tags'] as Map)[_a] as Map),
      'broken': {'v': true},
      'future': {'at': 9, 'v': true, 'weight': 3},
    };
    (json['lists'] as Map)['bad'] = 'not a list';
    final read = SyncSnapshot.decode(jsonEncode(json))!;
    expect(read.tags[_a]!.keys, containsAll(['travel', 'nature', 'future']));
    expect(read.tags[_a]!.containsKey('broken'), isFalse);
    expect(read.lists.keys, ['l1', 'l2']);
    expect(read.searches['s1']!.value!.query, 'pool');
  });

  test('anything that is not a sync file is refused', () {
    expect(SyncSnapshot.decode('not json'), isNull);
    expect(SyncSnapshot.decode('{"format": 1}'), isNull);
    expect(SyncSnapshot.decode('{"device": {"id": "x"}}'), isNull);
    expect(SyncSnapshot.decode('[1, 2]'), isNull);
  });

  test('nothing of the server travels: no address, user or password field '
      'exists to write', () {
    final text = _full().encode();
    for (final word in ['password', 'username', 'server_url', 'active_url']) {
      expect(text, isNot(contains(word)));
    }
  });
}
