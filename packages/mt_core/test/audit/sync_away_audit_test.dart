import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

const _trip = 'https://www.youtube.com/watch?v=trip0000000';
const _talk = 'https://www.youtube.com/watch?v=talk0000000';
const _day = 24 * 60 * 60 * 1000;

SyncSnapshot _device(
  String id, {
  Map<String, Map<String, Stamped<bool>>> tags = const {},
  int writtenAt = 0,
}) => SyncSnapshot(
  deviceId: id,
  deviceKind: id.split('-').first,
  writtenAt: writtenAt,
  tags: tags,
);

/// Setting aside a returning device's old data is there so it does not
/// bring back what others deleted; with nobody else to say anything, its
/// own data must survive the return.
void main() {
  test(
    'alone in the folder, a device away 91 days keeps its own tags',
    () {
      final me = _device(
        'ember-c3d4',
        tags: {
          _trip: {'travel': const Stamped(true, 1 * _day)},
        },
      );
      final out = SyncMerge.forDevice(
        mine: me,
        others: const [],
        now: 95 * _day,
        lastSync: 2 * _day,
      );
      expect(out.snapshot.tags[_trip]?['travel']?.removed, isFalse);
    },
    skip: 'Known defect found by the pre-release audit; unskip with the fix',
  );

  test(
    "a quiet device's old file does not bring back a removal once forgotten",
    () {
      final laptop = _device(
        'ember-lap1',
        writtenAt: 1 * _day,
        tags: {
          _talk: {'calm': const Stamped(true, 1 * _day)},
        },
      );
      final phone = _device(
        'phone-a1b2',
        tags: {
          _talk: {'calm': const Stamped.removed(10 * _day)},
        },
      );
      var out = SyncMerge.forDevice(
        mine: phone,
        others: [laptop],
        now: 101 * _day,
        lastSync: 100 * _day,
      );
      out = SyncMerge.forDevice(
        mine: out.snapshot,
        others: [laptop],
        now: 102 * _day,
        lastSync: 101 * _day,
      );
      expect(out.snapshot.tags[_talk]?['calm']?.removed ?? true, isTrue);
    },
    skip: 'Known defect found by the pre-release audit; unskip with the fix',
  );
}
