import 'dart:async';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// A height outside YouTube is a ceiling the site may not be able to meet:
/// MeTube's selector for 720 has nothing after `best[height<=720]`, so a
/// clip with no listed heights failed outright. The engine now retries such
/// a refusal once at `best`, and changes nothing else.
void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mtf_height_');
  });
  tearDown(() => tempDir.delete(recursive: true));

  const tiktok = 'https://www.tiktok.com/@u/video/7301234567890123456';
  const youtube = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  const noFormat =
      'ERROR: [TikTok] 7301234567890123456: Requested format is not available. '
      'Use --list-formats for a list of available formats';

  Map<String, dynamic> failed(String url, [String msg = noFormat]) => {
    'id': 'x',
    'title': 'clip',
    'url': url,
    'status': 'error',
    'msg': msg,
  };
  Map<String, dynamic> finished(String url) => {
    'id': 'x',
    'title': 'clip',
    'url': url,
    'status': 'finished',
    'filename': 'clip.mp4',
  };
  Map<String, dynamic> running(String url) => {
    'id': 'x',
    'title': 'clip',
    'url': url,
    'status': 'downloading',
  };

  DownloadEngine makeEngine(FakeApi api) => DownloadEngine(
    api: api,
    policy: DeletePolicy.keepOnServer,
    maxPollAttempts: 6,
    pollInterval: Duration.zero,
    savePathBuilder: (task, name) => '${tempDir.path}/$name',
    transfer: Transfer(api: api, backoff: const [Duration.zero]),
    shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
  );

  Future<DownloadTask> run(FakeApi api, String url, Quality quality) async {
    final engine = makeEngine(api);
    addTearDown(engine.dispose);
    final task = engine.submit(url, quality);
    return engine.updates
        .firstWhere((t) => t.id == task.id && t.isFinished)
        .timeout(const Duration(seconds: 5));
  }

  test(
    '**the guard**: 720 with no such format on TikTok arrives at best',
    () async {
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(done: [failed(tiktok)]),
          // The retry reads again before its add, the failure still there.
          historyWith(done: [failed(tiktok)]),
          // While the retry runs, the old failure stays in the done list:
          // it must not fail the new attempt.
          historyWith(done: [failed(tiktok)], queue: [running(tiktok)]),
          historyWith(done: [finished(tiktok)]),
        ],
      );
      final result = await run(api, tiktok, Quality.q720);
      expect(result.phase, TaskPhase.completed);
      expect(result.quality, Quality.best);
      expect(api.adds, [(tiktok, Quality.q720), (tiktok, Quality.best)]);
    },
  );

  test('YouTube keeps its refusal: no retry', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(),
        historyWith(done: [failed(youtube)]),
      ],
    );
    final result = await run(api, youtube, Quality.q720);
    expect(result.phase, TaskPhase.failed);
    expect(api.adds, hasLength(1));
  });

  test('another refusal is not a missing height: no retry', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(),
        historyWith(done: [failed(tiktok, 'ERROR: Video unavailable')]),
      ],
    );
    final result = await run(api, tiktok, Quality.q720);
    expect(result.phase, TaskPhase.failed);
    expect(result.error, isA<ServerErrorException>());
    expect(api.adds, hasLength(1));
  });

  test('best that fails is not retried', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(),
        historyWith(done: [failed(tiktok)]),
      ],
    );
    final result = await run(api, tiktok, Quality.best);
    expect(result.phase, TaskPhase.failed);
    expect(api.adds, hasLength(1));
  });

  test('a retry that fails too fails the task, once: no loop', () async {
    var call = 0;
    final api = FakeApi(historyScript: [historyWith()])
      ..onHistoryFetch = (c) => call = c;
    // From the first poll on, every reading holds a fresh failure.
    api.historyScript = [
      historyWith(),
      historyWith(done: [failed(tiktok)]),
      historyWith(done: [failed(tiktok)]),
      historyWith(done: [failed(tiktok, '$noFormat ')]),
    ];
    final result = await run(api, tiktok, Quality.q1080);
    expect(result.phase, TaskPhase.failed);
    expect(api.adds, [(tiktok, Quality.q1080), (tiktok, Quality.best)]);
    expect(call, lessThan(10));
  });
}
