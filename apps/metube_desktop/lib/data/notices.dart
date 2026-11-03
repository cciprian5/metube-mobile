import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import '../di.dart';
import 'local_copies.dart';

/// A button on a Windows notification.
typedef NoticeAction = ({String label, void Function() onPressed});

/// A Windows notification, as the app asks for one.
class EmberNotice {
  const EmberNotice({
    required this.title,
    required this.body,
    this.actions = const [],
    this.onClick,
  });

  final String title;
  final String body;
  final List<NoticeAction> actions;
  final void Function()? onClick;
}

/// Where notices go: Windows' own in main, nowhere in tests.
abstract class NoticePort {
  Future<void> show(EmberNotice notice);
}

class NoNotices implements NoticePort {
  const NoNotices();

  @override
  Future<void> show(EmberNotice notice) async {}
}

final noticePortProvider = Provider<NoticePort>((ref) => const NoNotices());

/// Whether the window is in front, where the downloads panel already says
/// what a notice would; main asks Windows.
final windowInFrontProvider = Provider<Future<bool> Function()>(
  (ref) =>
      () async => false,
);

/// Brings the window back from the tray or from behind, for a notice's
/// click; main puts Windows' in.
final bringWindowBackProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);

/// The tasks that reached an end since [before] (their phases by id), in
/// the order of [now]. A task first seen already ended is not news: it
/// ended before this run was watching.
List<DownloadTask> newlyEnded(
  Map<String, TaskPhase> before,
  List<DownloadTask> now,
) => [
  for (final task in now)
    if ((task.phase == TaskPhase.completed || task.phase == TaskPhase.failed) &&
        before.containsKey(task.id) &&
        before[task.id] != task.phase)
      task,
];

/// The copies to this computer that ended since [before], as above.
List<LocalCopy> newlyEndedCopies(
  Map<String, CopyPhase> before,
  List<LocalCopy> now,
) => [
  for (final copy in now)
    if ((copy.phase == CopyPhase.done || copy.phase == CopyPhase.failed) &&
        before.containsKey(copy.id) &&
        before[copy.id] != copy.phase)
      copy,
];

/// **What arrived by itself**: clips a followed channel brought to the
/// server, which no task of this app announces. The same rules as the
/// phone's watcher, against the library rather than `/history`:
///
/// - a set of keys, not a time: MeTube stamps an item when it is created,
///   and an arrival is an item finishing;
/// - the first run says nothing, or the whole library would have "just
///   arrived";
/// - nor does another server: a library with not one key in common is a
///   different library, not a thousand arrivals;
/// - what this app sent is the engine's to announce, not this.
class Arrivals {
  Arrivals(this._ref);

  static const key = 'ember_arrivals_seen';

  final Ref _ref;
  Set<String>? _seen;
  var _loaded = false;
  var _busy = false;

  /// The clips that arrived since the last look, newest first; empty on a
  /// first run, another server, or nothing new.
  Future<List<LibraryItem>> check(
    List<LibraryItem> items, {
    required Set<String> mine,
  }) async {
    // Two looks at once would both read the old set and announce twice.
    if (_busy) return const [];
    _busy = true;
    try {
      return await _check(items, mine);
    } finally {
      _busy = false;
    }
  }

  Future<List<LibraryItem>> _check(
    List<LibraryItem> items,
    Set<String> mine,
  ) async {
    final onServer = [
      for (final item in items)
        if (item.onServer && item.serverFilename != null) item,
    ];
    if (onServer.isEmpty) return const [];
    final now = {for (final item in onServer) item.canonicalUrl};
    final store = _ref.read(keyValueStoreProvider);
    if (!_loaded) {
      final kept = await store.getStringList(key);
      _seen = kept?.toSet();
      _loaded = true;
    }
    final seen = _seen;
    if (seen == null || (seen.isNotEmpty && !now.any(seen.contains))) {
      await _save(now);
      return const [];
    }
    final arrived = [
      for (final item in onServer)
        if (!seen.contains(item.canonicalUrl) &&
            !mine.contains(item.canonicalUrl))
          item,
    ]..sort((a, b) => _when(b).compareTo(_when(a)));
    if (arrived.isNotEmpty ||
        seen.length != now.length ||
        !seen.containsAll(now)) {
      await _save(now);
    }
    return arrived;
  }

  static DateTime _when(LibraryItem item) =>
      item.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _save(Set<String> keys) async {
    _seen = keys;
    final store = _ref.read(keyValueStoreProvider);
    await _ref
        .read(prefsMutexProvider)
        .run(() => store.setStringList(key, keys.toList()));
  }
}

final arrivalsProvider = Provider<Arrivals>(Arrivals.new);

/// Who posted an arrived clip, from its public address.
final arrivalAuthorProvider = Provider<ClipAuthorLookup>(
  (ref) => clipAuthorFrom(ClipPreviewResolver()),
);
