part of 'download_engine.dart';

/// The text yt-dlp gives when no format passes the height ceiling. MeTube
/// turns a numeric quality into `bestvideo[height<=N]+bestaudio/best[height<=N]`
/// with nothing after it, so a clip whose formats carry no height, or whose
/// only format is taller than N, fails instead of downloading.
const _noFormatAtHeight = 'requested format is not available';

/// Does [error] mean "nothing at this height", for a task whose quality is a
/// ceiling the site might not honour? YouTube always lists its heights, so
/// a refusal there is something else and is left as it was.
bool _heightFallbackApplies(DownloadTask task, MTApiException error) =>
    task.quality.isNumeric &&
    error is ServerErrorException &&
    error is! PlatformBlockedException &&
    !MediaPlatform.detect(task.effectiveUrl).isYouTube &&
    (error.detail ?? '').toLowerCase().contains(_noFormatAtHeight);

/// **The add, with one retry at `best`.** Outside YouTube a height is a
/// wish: when the site cannot meet it the clip still arrives, at the best
/// the site has, rather than failing. A part file for the same reason as
/// the others: it works on the engine's private state.
extension DownloadEngineAdd on DownloadEngine {
  Future<HistoryItem> _addAndPoll(
    String taskId,
    DownloadTask task,
    String resolved,
  ) async {
    try {
      return await _addOnce(taskId, task, resolved);
    } on ServerErrorException catch (e) {
      if (!_heightFallbackApplies(task, e)) rethrow;
      onLog?.call('no ${task.quality.wire} format, retrying at best');
      final retry = _emit(
        task.copyWith(quality: Quality.best, phase: TaskPhase.adding),
      );
      return _addOnce(taskId, retry, resolved);
    }
  }

  Future<HistoryItem> _addOnce(
    String taskId,
    DownloadTask task,
    String resolved,
  ) async {
    // Know what existed before us, so another operation is
    // never attributed to this task. **One reading serves both jobs**: the
    // fingerprints of this URL's items for the fallback match, and the whole
    // server so the one thing our add changes can be identified by key.
    // Read again for the retry: the failure just left is now "before", so
    // the new attempt is never mistaken for it.
    final history = await _matcher.read();
    _snapshots[taskId] = HistoryMatcher.signaturesFor(
      history,
      task.effectiveUrl,
    );
    _fingerprints[taskId] = history == null
        ? null
        : HistoryMatcher.fingerprints(history);
    // **Before the add, not after**: the point of the record is to survive
    // a death, and the most likely moment to die is while the server is
    // working — which begins on the next line.
    _remember(task, before: _snapshots[taskId]);
    _throwIfCancelRequested(taskId);
    await api.add(
      resolved,
      task.quality,
      compatibleVideo: compatibleVideo?.call() ?? false,
      folder: task.folder,
    );
    final polling = _emit(task.copyWith(phase: TaskPhase.polling));
    return _pollUntilDone(taskId, polling);
  }
}
