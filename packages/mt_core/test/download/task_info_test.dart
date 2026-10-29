import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// A task shows its title and picture while the server is still fetching
/// it: until the file was done, the downloads list showed a bare link and
/// a blank where the cover goes.
void main() {
  const inputUrl = 'https://youtu.be/dQw4w9WgXcQ';
  const canonical = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  const cover = 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg';

  Map<String, dynamic> item(String status, {String? file}) => {
    'id': 'dQw4w9WgXcQ',
    'title': 'Never Gonna Give You Up',
    'thumbnail': cover,
    'url': canonical,
    'status': status,
    'percent': 12.5,
    'filename': ?file,
  };

  DownloadEngine engine(FakeApi api) => DownloadEngine(
    api: api,
    policy: DeletePolicy.keepOnServer,
    pullToDevice: false,
    pollInterval: const Duration(milliseconds: 10),
    maxPollAttempts: 50,
    savePathBuilder: (t, f) => throw StateError('no path in server mode'),
    shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
  );

  test('**the guard**: a task still downloading carries the title and the '
      'cover the server lists for it', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(),
        historyWith(queue: [item('downloading')]),
        historyWith(queue: [item('downloading')]),
        historyWith(done: [item('finished', file: 'clip.mp4')]),
      ],
    );
    final e = engine(api);
    addTearDown(e.dispose);
    // Before the server named the file: the clip is still coming.
    final whileRunning = <DownloadTask>[];
    e.updates.listen((t) {
      if (t.phase == TaskPhase.polling && t.serverFilename == null) {
        whileRunning.add(t);
      }
    });
    final task = e.submit(inputUrl, Quality.best);
    await e.updates
        .firstWhere((t) => t.id == task.id && t.isFinished)
        .timeout(const Duration(seconds: 3));
    expect(
      whileRunning.map((t) => t.thumbnail),
      contains(cover),
      reason: 'the cover is known while the clip is still coming',
    );
    expect(whileRunning.map((t) => t.title), contains('Never Gonna Give You Up'));
  });
}
