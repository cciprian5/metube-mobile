import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';

PlaylistItem _item(String id) => PlaylistItem(
  canonicalUrl: 'https://x/$id',
  title: id,
  serverFilename: '$id.mp4',
);

final _five = [
  for (final id in ['a', 'b', 'c', 'd', 'e']) _item(id),
];

void main() {
  group('the ordinary order', () {
    test('it starts at the requested index', () {
      final queue = PlaybackQueue(items: _five, index: 2);
      expect(queue.current!.title, 'c');
      expect(queue.index, 2);
    });

    test('an index out of range is clamped', () {
      expect(PlaybackQueue(items: _five, index: 99).index, 4);
      expect(PlaybackQueue(items: _five, index: -3).index, 0);
    });

    test('an empty list: no current and no next', () {
      final queue = PlaybackQueue(items: const []);
      expect(queue.current, isNull);
      expect(queue.index, -1);
      expect(queue.nextIndex(PlayMode.autoNext), isNull);
    });
  });

  group('the play modes', () {
    test('automatic: the next, then it stops at the end', () {
      final queue = PlaybackQueue(items: _five, index: 3);
      expect(queue.nextIndex(PlayMode.autoNext), 4);
      queue.jumpTo(4);
      expect(queue.nextIndex(PlayMode.autoNext), isNull);
    });

    test('repeat all wraps from the end to the start, and back', () {
      final queue = PlaybackQueue(items: _five, index: 4);
      expect(queue.nextIndex(PlayMode.repeatAll), 0);
      queue.jumpTo(0);
      expect(queue.previousIndex(PlayMode.repeatAll), 4);
    });

    test('stop at the end does not wrap', () {
      final queue = PlaybackQueue(items: _five, index: 4);
      expect(queue.nextIndex(PlayMode.stopAtEnd), isNull);
    });

    test('repeat one: on its own it replays itself', () {
      final queue = PlaybackQueue(items: _five, index: 1);
      expect(queue.nextIndex(PlayMode.repeatOne), 1);
    });

    test('repeat one does not trap the user who presses next', () {
      final queue = PlaybackQueue(items: _five, index: 1);
      expect(queue.nextIndex(PlayMode.repeatOne, userInitiated: true), 2);
      queue.jumpTo(4);
      expect(queue.nextIndex(PlayMode.repeatOne, userInitiated: true), 0);
    });

    test('previous from the head of the list, with no repeat, is nothing', () {
      final queue = PlaybackQueue(items: _five);
      expect(queue.previousIndex(PlayMode.autoNext), isNull);
    });
  });

  group('shuffle', () {
    test('it starts at the current item and covers every item once', () {
      final queue = PlaybackQueue(
        items: _five,
        index: 3,
        shuffle: true,
        random: Random(7),
      );
      expect(queue.current!.title, 'd');
      expect(queue.ordered.first.title, 'd');
      expect(queue.ordered.map((i) => i.title).toSet().length, 5);
    });

    test('it passes over every item without repeating, to the end', () {
      final queue = PlaybackQueue(
        items: _five,
        shuffle: true,
        random: Random(3),
      );
      final visited = <String>[queue.current!.title];
      while (queue.moveNext(PlayMode.autoNext)) {
        visited.add(queue.current!.title);
      }
      expect(visited.toSet().length, 5);
    });

    test('turning shuffle off restores the original order and keeps the current item', () {
      final queue = PlaybackQueue(
        items: _five,
        index: 2,
        shuffle: true,
        random: Random(11),
      );
      queue.setShuffle(false);
      expect(queue.current!.title, 'c');
      expect(queue.ordered.map((i) => i.title), ['a', 'b', 'c', 'd', 'e']);
      expect(queue.nextIndex(PlayMode.autoNext), 3);
    });
  });

  group(
    'removal, whether skipping something broken or removing from the sheet',
    () {
      test(
        'removing something other than the current keeps the current item',
        () {
          final queue = PlaybackQueue(items: _five, index: 3);
          expect(queue.removeAt(0), isTrue);
          expect(queue.current!.title, 'd');
          expect(queue.length, 4);
        },
      );

      test('removing the current moves to whatever took its place', () {
        final queue = PlaybackQueue(items: _five, index: 2);
        queue.removeAt(2);
        expect(queue.current!.title, 'd');
      });

      test('removing the last item while it is current falls back to the last one left', () {
        final queue = PlaybackQueue(items: _five, index: 4);
        queue.removeAt(4);
        expect(queue.current!.title, 'd');
      });

      test('removing everything leaves the queue empty', () {
        final queue = PlaybackQueue(items: [_item('only')]);
        queue.removeAt(0);
        expect(queue.isEmpty, isTrue);
        expect(queue.current, isNull);
      });

      test('an index out of range is refused', () {
        final queue = PlaybackQueue(items: _five);
        expect(queue.removeAt(9), isFalse);
        expect(queue.length, 5);
      });
    },
  );

  test('jumpTo refuses what is not in the queue', () {
    final queue = PlaybackQueue(items: _five);
    expect(queue.jumpTo(2), isTrue);
    expect(queue.jumpTo(50), isFalse);
    expect(queue.index, 2);
  });

  group('reordering "up next"', () {
    List<String> titles(PlaybackQueue q) => [
      for (final i in q.ordered) i.title,
    ];

    test('a later item moved up plays next, the current one plays on', () {
      final queue = PlaybackQueue(items: _five, index: 1); // b
      expect(queue.moveOrdered(4, 2), isTrue); // e right after b
      expect(titles(queue), ['a', 'b', 'e', 'c', 'd']);
      expect(queue.current!.title, 'b');
      expect(queue.moveNext(PlayMode.autoNext), isTrue);
      expect(queue.current!.title, 'e');
    });

    test('**the guard**: moving the current item keeps it current', () {
      final queue = PlaybackQueue(items: _five, index: 1); // b
      queue.moveOrdered(1, 3);
      expect(titles(queue), ['a', 'c', 'd', 'b', 'e']);
      expect(queue.current!.title, 'b');
      // Moving one from before it past it shifts it back a place.
      queue.moveOrdered(0, 4);
      expect(titles(queue), ['c', 'd', 'b', 'e', 'a']);
      expect(queue.current!.title, 'b');
      expect(queue.moveNext(PlayMode.autoNext), isTrue);
      expect(queue.current!.title, 'e');
    });

    test('the same clip twice: the cursor follows its place, not its name', () {
      final b = _item('b');
      final queue = PlaybackQueue(
        items: [_item('a'), b, _item('c'), b],
        index: 3,
      );
      queue.moveOrdered(0, 2);
      expect(queue.index, 3);
      expect(queue.moveNext(PlayMode.autoNext), isFalse);
    });

    test('a sequential reorder survives shuffle on and off', () {
      final queue = PlaybackQueue(items: _five, index: 0);
      queue.moveOrdered(4, 1);
      queue
        ..setShuffle(true)
        ..setShuffle(false);
      expect(titles(queue), ['a', 'e', 'b', 'c', 'd']);
    });

    test('under shuffle only the shuffled order changes', () {
      final queue = PlaybackQueue(
        items: _five,
        index: 0,
        shuffle: true,
        random: Random(7),
      );
      final before = titles(queue);
      final current = queue.current!.title;
      queue.moveOrdered(4, 1);
      expect(titles(queue), [before[0], before[4], ...before.sublist(1, 4)]);
      expect(queue.current!.title, current);
      expect([for (final i in queue.items) i.title], ['a', 'b', 'c', 'd', 'e']);
    });

    test('positions out of range change nothing', () {
      final queue = PlaybackQueue(items: _five);
      expect(queue.moveOrdered(-1, 2), isFalse);
      expect(queue.moveOrdered(1, 5), isFalse);
      expect(titles(queue), ['a', 'b', 'c', 'd', 'e']);
    });
  });

  group('play next', () {
    List<String> order(PlaybackQueue q) => [for (final i in q.ordered) i.title];

    test('**the guard**: it goes right after the current one, and what plays '
        'stays current', () {
      final queue = PlaybackQueue(items: _five, index: 1)
        ..insertNext(_item('x'));
      expect(queue.current!.title, 'b');
      expect(order(queue), ['a', 'b', 'x', 'c', 'd', 'e']);
      expect(queue.moveNext(PlayMode.autoNext), isTrue);
      expect(queue.current!.title, 'x');
    });

    test('under shuffle too, without reshuffling the rest', () {
      final queue = PlaybackQueue(
        items: _five,
        index: 2,
        shuffle: true,
        random: Random(5),
      );
      final before = order(queue);
      queue.insertNext(_item('x'));
      expect(queue.current!.title, 'c');
      expect(order(queue), [before.first, 'x', ...before.skip(1)]);
    });

    test('an empty queue takes it as its only item', () {
      final queue = PlaybackQueue(items: const [])..insertNext(_item('x'));
      expect(queue.current!.title, 'x');
    });
  });
}
