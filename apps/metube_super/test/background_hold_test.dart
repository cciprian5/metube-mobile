import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/home/background_hold.dart';

void main() {
  late List<String> calls;
  late bool starts;
  late BackgroundHold hold;

  setUp(() {
    calls = [];
    starts = true;
    hold = BackgroundHold(
      start: () async {
        calls.add('start');
        return starts;
      },
      stop: () async => calls.add('stop'),
    );
  });

  test('**the guard**: a share ending does not stop the service a '
      'download still needs', () async {
    await hold.set('downloads', true);
    await hold.set('share', true);
    await hold.set('share', false);
    expect(calls, ['start'], reason: 'the download would freeze');
    await hold.set('downloads', false);
    expect(calls, ['start', 'stop']);
  });

  test('the same news twice changes nothing', () async {
    await hold.set('downloads', true);
    await hold.set('downloads', true);
    await hold.set('downloads', false);
    await hold.set('downloads', false);
    expect(calls, ['start', 'stop']);
  });

  test('a start that failed is tried again on the next call', () async {
    starts = false;
    await hold.set('downloads', true);
    starts = true;
    await hold.set('downloads', true);
    expect(calls, ['start', 'start']);
  });
}
