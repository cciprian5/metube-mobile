import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';

/// A download engine that records what it is given and sends nothing; a
/// test moves a task along with [fail] or [finish].
class FakeEngine extends Fake implements DownloadEngine {
  final List<DownloadTask> submitted = [];
  final _updates = StreamController<DownloadTask>.broadcast();
  final _tasks = <String, DownloadTask>{};

  @override
  DownloadTask submit(
    String url,
    Quality quality, {
    bool isBatchMember = false,
    String? folder,
  }) {
    final task = DownloadTask(
      inputUrl: url,
      quality: quality,
      isBatchMember: isBatchMember,
      folder: folder,
    );
    submitted.add(task);
    _put(task);
    return task;
  }

  void _put(DownloadTask task) {
    _tasks[task.id] = task;
    _updates.add(task);
  }

  void fail(DownloadTask task, MTApiException error) =>
      _put(task.copyWith(phase: TaskPhase.failed, error: error));

  void finish(DownloadTask task) =>
      _put(task.copyWith(phase: TaskPhase.completed));

  /// What was cancelled and forgotten, by task id.
  final List<String> cancelled = [];
  final List<String> forgotten = [];

  @override
  void cancel(String taskId) {
    cancelled.add(taskId);
    if (_tasks[taskId] case final task?) {
      _put(task.copyWith(phase: TaskPhase.cancelled));
    }
  }

  @override
  void forget(String taskId) {
    forgotten.add(taskId);
    _tasks.remove(taskId);
    _updates.add(DownloadTask(inputUrl: '', quality: Quality.best));
  }

  @override
  Stream<DownloadTask> get updates => _updates.stream;

  @override
  DownloadTask? taskById(String id) => _tasks[id];

  @override
  List<DownloadTask> get tasks => _tasks.values.toList();

  @override
  Future<void> dispose() async {}
}
