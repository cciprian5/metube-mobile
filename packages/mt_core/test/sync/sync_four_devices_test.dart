import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

const _clip = 'https://www.youtube.com/watch?v=clip0000000';
const _day = 24 * 60 * 60 * 1000;

SyncSnapshot _device(
  String id, {
  Map<String, Stamped<bool>> tags = const {},
  int writtenAt = 0,
}) => SyncSnapshot(
  deviceId: id,
  deviceKind: id.split('-').first,
  writtenAt: writtenAt,
  tags: tags.isEmpty ? const {} : {_clip: tags},
);

Set<String> _on(SyncSnapshot s) => {
  for (final MapEntry(:key, :value) in (s.tags[_clip] ?? const {}).entries)
    if (!value.removed) key,
};

/// **Four devices in one folder** (two phones, two computers), as the sync
/// plan asks before it is called done: they read each other in any order
/// and end up the same, and one back after four months does not undo what
/// the others deleted while it was off.
void main() {
  test('**the guard**: tags added on two devices at once both survive, '
      'whichever order the four read each other', () {
    final now = 20 * _day;
    final devices = [
      _device(
        'phone-a1b2',
        writtenAt: now,
        tags: {'travel': const Stamped(true, 10 * _day)},
      ),
      _device(
        'phone-c3d4',
        writtenAt: now,
        tags: {'calm': const Stamped(true, 10 * _day)},
      ),
      _device('ember-e5f6', writtenAt: now),
      _device(
        'ember-a7b8',
        writtenAt: now,
        tags: {'old': const Stamped.removed(12 * _day)},
      ),
    ];
    final results = <Set<String>>[];
    for (final order in [
      [0, 1, 2, 3],
      [3, 2, 1, 0],
      [2, 0, 3, 1],
    ]) {
      var merged = devices[order.first];
      for (final i in order.skip(1)) {
        merged = SyncMerge.merge(merged, devices[i]);
      }
      results.add(_on(merged));
    }
    for (final result in results) {
      expect(result, {'travel', 'calm'});
    }
  });

  test('**the guard**: back after 120 days, a device does not bring back '
      'what the others deleted, and is told it came back', () {
    final now = 130 * _day;
    final away = _device(
      'phone-c3d4',
      writtenAt: 5 * _day,
      tags: {
        'travel': const Stamped(true, 1 * _day),
        'kept': const Stamped(true, 2 * _day),
      },
    );
    // The others removed "travel" on day 10 and have since forgotten it;
    // "kept" is still on everywhere.
    final others = [
      _device(
        'phone-a1b2',
        writtenAt: now - _day,
        tags: {'kept': const Stamped(true, 2 * _day)},
      ),
      _device('ember-e5f6', writtenAt: now - _day),
      _device('ember-a7b8', writtenAt: now - 2 * _day),
    ];
    final out = SyncMerge.forDevice(
      mine: away,
      others: others,
      now: now,
      lastSync: 5 * _day,
    );
    expect(out.cameBack, isTrue);
    expect(_on(out.snapshot), {'kept'});
  });

  test('a tag added since coming back is kept', () {
    final now = 130 * _day;
    final out = SyncMerge.forDevice(
      mine: _device(
        'phone-c3d4',
        tags: {'new': Stamped(true, now - 60 * 1000)},
      ),
      others: [_device('ember-e5f6', writtenAt: now - _day)],
      now: now,
      lastSync: 5 * _day,
    );
    expect(_on(out.snapshot), {'new'});
  });
}
