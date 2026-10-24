import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import '../di.dart';
import '../platform/desktop_policy.dart';
import 'library_data.dart';
import 'local_copies.dart';
import 'lists_data.dart';
import 'transcripts_data.dart';

/// The saved key of "fetch the transcript first", the phone's own, so a
/// backup carries the choice either way.
const transcriptsFirstKey = 'transcripts_enabled';

/// Whether the transcript is fetched before a YouTube clip is added; on
/// unless turned off, as on the phone.
final transcriptsFirstProvider =
    NotifierProvider<TranscriptsFirstNotifier, bool>(
      TranscriptsFirstNotifier.new,
    );

class TranscriptsFirstNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref
        .read(keyValueStoreProvider)
        .getBool(transcriptsFirstKey)
        .then((saved) => state = saved ?? true, onError: (_) {});
    return true;
  }

  Future<void> set(bool on) {
    state = on;
    return ref
        .read(prefsMutexProvider)
        .run(
          () =>
              ref.read(keyValueStoreProvider).setBool(transcriptsFirstKey, on),
        );
  }
}

/// How captions are fetched; a test puts its own in.
final captionsFetcherFactoryProvider =
    Provider<CaptionsFetcher Function(MeTubeApi)>((ref) => CaptionsFetcher.new);

/// Collects a playlist's clips into one saved list as they arrive.
final batchCollectorProvider = Provider(
  (ref) => BatchPlaylistCollector(
    playlists: ref.watch(playlistsStoreProvider),
    onChanged: () => ref.invalidate(playlistsProvider),
  ),
);

/// The one download engine, null without a server. **Everything stays on
/// the server** (the policy is fixed for this app, never a setting), and
/// nothing is pulled to this computer here: that is the offline copy's
/// and the download folder's work.
final downloadEngineProvider = Provider<DownloadEngine?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final collector = ref.watch(batchCollectorProvider);
  final engine = DownloadEngine(
    api: api,
    policy: const DesktopPolicy().deletePolicy,
    pullToDevice: false,
    pollNetworkTolerance: MTConstants.pollNetworkTolerance,
    savePathBuilder: (_, _) => throw StateError('nothing is pulled here'),
    onCompleted: (task) {
      collector.onFinished(task);
      ref.invalidate(historyProvider);
      pullAfterFinished(
        pulls: ref.read(pullAfterProvider),
        copies: ref.read(localCopiesProvider.notifier),
        task: task,
      );
    },
    beforeAdd: (task) => _transcriptFirst(ref, task, api),
  );
  final dropped = engine.updates.listen((task) {
    if (task.phase == TaskPhase.failed || task.phase == TaskPhase.cancelled) {
      collector.onDropped(task.id);
    }
  });
  ref.onDispose(() {
    dropped.cancel();
    engine.dispose();
  });
  return engine;
});

/// The tasks whose file is to be saved on this computer once the server
/// has it ("then download it to this computer" in the add dialog), each
/// with the folder picked for it, or null for the download folder.
final pullAfterProvider = Provider<Map<String, String?>>((ref) => {});

/// A finished task asked to come to this computer goes to the copies; the
/// server keeps its own, as always here. Anything else is left alone.
void pullAfterFinished({
  required Map<String, String?> pulls,
  required LocalCopies copies,
  required DownloadTask task,
}) {
  if (!pulls.containsKey(task.id)) return;
  final into = pulls.remove(task.id);
  final path = task.serverFilename;
  final url = task.canonicalUrl;
  if (path == null || url == null) return;
  copies.download((
    canonicalUrl: url,
    title: task.title ?? ServerPath.basename(path),
    serverPath: path,
    thumbnail: task.thumbnail,
  ), into: into).ignore();
}

/// The engine's tasks, first as they are, then at each change.
final engineTasksProvider = StreamProvider<List<DownloadTask>>((ref) async* {
  final engine = ref.watch(downloadEngineProvider);
  if (engine == null) {
    yield const [];
    return;
  }
  yield engine.tasks;
  yield* engine.updates.map((_) => engine.tasks);
});

/// What the downloads button counts: clips the server is still fetching,
/// and copies coming to this computer.
final activeDownloadsProvider = Provider<int>((ref) {
  final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
  return tasks.where((t) => !t.isFinished).length +
      ref.watch(activeCopiesProvider);
});

/// The engine's hook, run before each clip is added: the transcript of a
/// single YouTube clip, in the reader's language then English, kept on
/// this computer. A playlist's clips are skipped (fifty would each wait
/// for theirs), and it never throws: the clip is added whatever happens.
Future<void> _transcriptFirst(Ref ref, DownloadTask task, MeTubeApi api) async {
  if (task.isBatchMember || !ref.read(transcriptsFirstProvider)) return;
  final store = ref.read(transcriptStoreProvider);
  final url = task.effectiveUrl;
  if (store == null || PlaylistDetector.isPlaylist(url)) return;
  if (UrlKit.youtubeVideoId(url) == null) return;
  final fetcher = ref.read(captionsFetcherFactoryProvider)(api);
  final own = PlatformDispatcher.instance.locale.languageCode;
  for (final language in {own, 'en'}) {
    try {
      final result = await fetcher.fetch(url, language: language);
      if (result.transcript case final transcript?) {
        await keepTranscript(ref, store, transcript);
      }
      // A server that failed once will likely fail again, and each try
      // holds the clip back.
      if (result.outcome != CaptionsOutcome.fetched &&
          result.outcome != CaptionsOutcome.none) {
        return;
      }
    } on Object {
      return;
    }
  }
}

/// The folders the server would save into, asked when a picker opens and
/// forgotten when it closes, so a folder made since shows next time.
final serverFoldersProvider = FutureProvider.autoDispose<ServerFolders?>(
  (ref) async => ref.watch(apiClientProvider)?.fetchFolders(),
);

/// The folders the library's clips sit in.
final libraryFolderPathsProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
  return {for (final item in items) ?item.folderPath};
});

/// Whether the server ignores the chosen folder ([foldersIgnored]).
final foldersIgnoredProvider = Provider<bool>(
  (ref) =>
      foldersIgnored(ref.watch(historyProvider).valueOrNull?.done ?? const []),
);
