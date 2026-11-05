import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

const _trip = 'https://www.youtube.com/watch?v=trip0000000';
const _talk = 'https://www.youtube.com/watch?v=talk0000000';
const _day = 24 * 60 * 60 * 1000;

SyncSnapshot _device(
  String id, {
  Map<String, Map<String, Stamped<bool>>> tags = const {},
  Map<String, Stamped<int>> positions = const {},
  Map<String, Stamped<SyncList>> lists = const {},
  Map<String, Map<String, Stamped<SyncMember>>> members = const {},
}) => SyncSnapshot(
  deviceId: id,
  deviceKind: id.split('-').first,
  tags: tags,
  positions: positions,
  lists: lists,
  members: members,
);

/// The data alone, without whose file it is, keys sorted at every level so
/// two maps holding the same facts read the same.
String _data(SyncSnapshot s) => jsonEncode(
  _sorted(
    jsonDecode(
      s.copyWith(deviceId: 'x', deviceKind: 'x', writtenAt: 0).encode(),
    ),
  ),
);

Object? _sorted(Object? json) => switch (json) {
  final Map<String, Object?> map => {
    for (final key in map.keys.toList()..sort()) key: _sorted(map[key]),
  },
  final List<Object?> list => [for (final v in list) _sorted(v)],
  _ => json,
};

void main() {
  final phone = _device(
    'phone-a1b2',
    tags: {
      _trip: {'travel': const Stamped(true, 1000)},
      _talk: {'calm': const Stamped.removed(3000)},
    },
    positions: {_talk: const Stamped(60000, 2000)},
    lists: {'evening': const Stamped(SyncList(name: 'Evening'), 1000)},
    members: {
      'evening': {_trip: const Stamped(SyncMember(title: 'Trip'), 1000)},
    },
  );
  final computer = _device(
    'ember-c3d4',
    tags: {
      _trip: {'nature': const Stamped(true, 1300)},
      _talk: {'calm': const Stamped(true, 2000)},
    },
    positions: {_talk: const Stamped(90000, 2500)},
    lists: {'evening': const Stamped(SyncList(name: 'Evenings'), 1500)},
    members: {
      'evening': {_talk: const Stamped(SyncMember(title: 'Talk'), 1500)},
    },
  );

  test(
    '**the guard**: two tags put on one clip from two devices both stay',
    () {
      final merged = SyncMerge.merge(phone, computer);
      expect(merged.tags[_trip]!.keys, containsAll(['travel', 'nature']));
      expect(merged.tags[_trip]!.values.every((s) => !s.removed), isTrue);
    },
  );

  test('a removal later than the tag wins, and stays won', () {
    final merged = SyncMerge.merge(computer, phone);
    expect(merged.tags[_talk]!['calm']!.removed, isTrue);
    expect(
      SyncMerge.merge(merged, computer).tags[_talk]!['calm']!.removed,
      isTrue,
    );
  });

  test('positions and list names follow the later change; members are '
      'joined per pair', () {
    final merged = SyncMerge.merge(phone, computer);
    expect(merged.positions[_talk]!.value, 90000);
    expect(merged.lists['evening']!.value!.name, 'Evenings');
    expect(merged.members['evening']!.keys, {_trip, _talk});
  });

  test('**commutative and idempotent**: a ⊕ b = b ⊕ a, and a ⊕ a = a', () {
    expect(
      _data(SyncMerge.merge(phone, computer)),
      _data(SyncMerge.merge(computer, phone)),
    );
    final once = SyncMerge.merge(phone, computer);
    expect(_data(SyncMerge.merge(once, once)), _data(once));
    expect(_data(SyncMerge.merge(once, phone)), _data(once));
    expect(_data(SyncMerge.merge(phone, phone)), _data(phone));
  });

  test('at the same moment a value beats a removal, whichever side', () {
    const kept = Stamped(true, 0);
    const gone = Stamped<bool>.removed(0);
    expect(SyncMerge.pick(kept, gone), kept);
    expect(SyncMerge.pick(gone, kept), kept);
  });

  test('removals are forgotten after 90 days, values never', () {
    final now = 200 * _day;
    final pruned = SyncMerge.prune(
      _device(
        'phone-a1b2',
        tags: {
          _trip: {
            'old': const Stamped.removed(10 * _day),
            'recent': Stamped.removed(150 * _day),
            'kept': const Stamped(true, 1),
          },
        },
      ),
      now: now,
    );
    expect(pruned.tags[_trip]!.keys, {'recent', 'kept'});
  });

  group('a device away longer than the removals are kept', () {
    // The laptop tagged the talk "calm" on day 1 and was then switched off.
    // The phone took the tag off on day 10; by day 130 the removal is
    // forgotten, and the phone's file says nothing about "calm" at all.
    final laptop = _device(
      'ember-lap1',
      tags: {
        _talk: {'calm': const Stamped(true, 1 * _day)},
      },
    );
    final phoneNow = _device(
      'phone-a1b2',
      tags: {
        _trip: {'travel': const Stamped(true, 5 * _day)},
      },
    );

    test('**the guard**: it does not bring back a tag deleted while it was '
        'off', () {
      final outcome = SyncMerge.forDevice(
        mine: laptop,
        others: [phoneNow],
        now: 130 * _day,
        lastSync: 2 * _day,
      );
      expect(outcome.cameBack, isTrue);
      expect(outcome.snapshot.tags[_talk], isNull);
      expect(outcome.snapshot.tags[_trip]!['travel']!.removed, isFalse);
    });

    test('what it changes after coming back is kept as usual', () {
      final back = laptop.copyWith(
        tags: {
          _talk: {
            'calm': const Stamped(true, 1 * _day),
            'focus': const Stamped(true, 129 * _day),
          },
        },
      );
      final outcome = SyncMerge.forDevice(
        mine: back,
        others: [phoneNow],
        now: 130 * _day,
        lastSync: 2 * _day,
      );
      expect(outcome.snapshot.tags[_talk]!.keys, {'focus'});
    });

    test('a device that synced recently keeps all of its own', () {
      final outcome = SyncMerge.forDevice(
        mine: laptop,
        others: [phoneNow],
        now: 30 * _day,
        lastSync: 29 * _day,
      );
      expect(outcome.cameBack, isFalse);
      expect(outcome.snapshot.tags[_talk]!['calm']!.removed, isFalse);
    });
  });

  test("its own file in the folder is not read as another device's", () {
    final outcome = SyncMerge.forDevice(
      mine: phone,
      others: [phone.copyWith(tags: const {})],
      now: 4000,
    );
    expect(outcome.snapshot.tags[_trip]!.keys, ['travel']);
  });
}
