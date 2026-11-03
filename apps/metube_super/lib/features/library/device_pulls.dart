import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart' show mtLocalizationsFor;

import '../../di.dart';
import '../home/background_hold.dart';
import '../home/download_watcher.dart' show notificationsProvider;
import 'share_job.dart' show TransferRate;

/// The silent notice that follows every copy to this phone while it runs.
const pullNoticeId = 770003;

/// Room kept free beyond the file itself, so a copy that just fits does
/// not leave the phone with nothing to work with.
const roomMargin = 200 * 1024 * 1024;

/// What a copy to this phone is for.
enum PullKind { offline, share }

/// One copy to this phone in flight.
class DevicePull {
  const DevicePull({
    required this.kind,
    required this.url,
    required this.title,
    this.received = 0,
    this.total = 0,
    this.rate,
  });

  final PullKind kind;
  final String url;
  final String title;
  final int received;

  /// Zero until the server says, unless the library already knew the size.
  final int total;

  /// Bytes a second, smoothed; null until there is enough to measure.
  final double? rate;

  double? get progress =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;

  static String keyOf(PullKind kind, String url) => '${kind.name}|$url';

  DevicePull copyWith({int? received, int? total, double? rate}) => DevicePull(
    kind: kind,
    url: url,
    title: title,
    received: received ?? this.received,
    total: total ?? this.total,
    rate: rate ?? this.rate,
  );
}

/// The phone has no room for the copy; said before a byte is downloaded.
class NotEnoughSpaceException implements Exception {
  const NotEnoughSpaceException({required this.needed, required this.free});

  final int needed;
  final int free;

  @override
  String toString() => 'NotEnoughSpaceException: needs $needed, $free free';
}

typedef PhonePull = Future<String> Function({
  required String serverFilename,
  required String savePath,
  required void Function(int received, int total) onBytes,
  required TransferCancel cancel,
});

/// The one pull every copy to this phone goes through. A provider so a
/// test can stand in for the network.
final phonePullProvider = Provider<PhonePull>(
  (ref) =>
      ({
        required serverFilename,
        required savePath,
        required onBytes,
        required cancel,
      }) {
        final api = ref.read(apiClientProvider);
        if (api == null) throw const NetworkException('no server configured');
        return Transfer(api: api).pull(
          serverFilename: serverFilename,
          savePath: savePath,
          onBytes: onBytes,
          cancel: cancel,
        );
      },
);

/// Free bytes where [path] lives; null when the phone does not say.
final freeBytesProvider = Provider<Future<int?> Function(String path)>(
  (ref) => (path) async {
    try {
      return await const MethodChannel('com.yasir.metubesuper/permissions')
          .invokeMethod<int>('freeBytes', {'path': path});
    } on Object {
      return null;
    }
  },
);

/// Fails before a copy the phone has no room for. An unknown size, or a
/// phone that does not answer, lets it through: guessing would block a
/// copy that fits.
Future<void> ensureRoom(Ref ref, String folder, int? size) async {
  if (size == null || size <= 0) return;
  final free = await ref.read(freeBytesProvider)(folder);
  if (free != null && free < size + roomMargin) {
    throw NotEnoughSpaceException(needed: size, free: free);
  }
}

final devicePullsProvider =
    NotifierProvider<DevicePulls, Map<String, DevicePull>>(DevicePulls.new);

/// Every copy to this phone in flight, offline copies and the copy a
/// share makes, keyed by what it is for and which clip.
///
/// One place, so the card, the downloads screen and the notice read the
/// same numbers and one copy finishing cannot wipe another's; the
/// background service is held while any runs; and a clip is never copied
/// twice for the same reason.
class DevicePulls extends Notifier<Map<String, DevicePull>> {
  final _cancels = <String, TransferCancel>{};
  final _rates = <String, TransferRate>{};
  final _shownAt = <String, Duration>{};
  final _clock = Stopwatch()..start();
  String? _notice;
  Duration? _noticeAt;

  @override
  Map<String, DevicePull> build() => const {};

  bool isRunning(PullKind kind, String url) =>
      state.containsKey(DevicePull.keyOf(kind, url));

  /// Null when this clip is already being copied for this reason.
  TransferCancel? begin(PullKind kind, String url, String title, {int? total}) {
    final key = DevicePull.keyOf(kind, url);
    if (state.containsKey(key)) return null;
    final cancel = _cancels[key] = TransferCancel();
    _rates[key] = TransferRate();
    state = {
      ...state,
      key: DevicePull(kind: kind, url: url, title: title, total: total ?? 0),
    };
    _changed();
    return cancel;
  }

  void report(PullKind kind, String url, int received, int total) {
    final key = DevicePull.keyOf(kind, url);
    final pull = state[key];
    if (pull == null) return;
    final at = _clock.elapsed;
    final rate = _rates[key]?.sample(received, at);
    final last = _shownAt[key];
    // Many reports a second would rebuild every screen for nothing.
    if (last != null &&
        at - last < const Duration(milliseconds: 200) &&
        received < total) {
      return;
    }
    _shownAt[key] = at;
    state = {
      ...state,
      key: pull.copyWith(received: received, total: total, rate: rate),
    };
    unawaited(_post());
  }

  void end(PullKind kind, String url) {
    final key = DevicePull.keyOf(kind, url);
    _cancels.remove(key);
    _rates.remove(key);
    _shownAt.remove(key);
    if (!state.containsKey(key)) return;
    state = Map.of(state)..remove(key);
    _changed();
  }

  void cancel(PullKind kind, String url) =>
      _cancels[DevicePull.keyOf(kind, url)]?.cancel();

  void _changed() {
    unawaited(ref.read(backgroundHoldProvider).set('phone', state.isNotEmpty));
    unawaited(_post());
  }

  /// One silent notice for every copy in flight, so leaving the app does
  /// not mean losing sight of how far they have got.
  Future<void> _post() async {
    final notices = ref.read(notificationsProvider);
    if (state.isEmpty) {
      if (_notice == null) return;
      _notice = null;
      return notices.cancel(pullNoticeId);
    }
    final pulls = state.values.toList();
    final known = pulls.every((p) => p.total > 0);
    final total = pulls.fold<int>(0, (sum, p) => sum + p.total);
    final received = pulls.fold<int>(0, (sum, p) => sum + p.received);
    final percent = known && total > 0 ? received * 100 ~/ total : null;
    final l10n = mtLocalizationsFor(ref.read(settingsProvider).localeCode);
    final only = pulls.length == 1 ? pulls.single : null;
    final title = only == null
        ? l10n.copyingToPhone(pulls.length)
        : only.kind == PullKind.share
        ? l10n.sharePreparing
        : l10n.pullingToDevice;
    final body = only?.title ?? pulls.map((p) => p.title).join(' · ');
    // Posted only when what it says changes, and the share done at most
    // once a second: past five posts a second Android drops them (measured,
    // "Shedding" in the system log), and the notice sat at its first value.
    final said = '$title|$body|$percent';
    if (said == _notice) return;
    final at = _clock.elapsed;
    final sameClips = _notice?.startsWith('$title|$body|') ?? false;
    if (sameClips &&
        _noticeAt != null &&
        at - _noticeAt! < const Duration(seconds: 1)) {
      return;
    }
    _notice = said;
    _noticeAt = at;
    await notices.showProgress(
      pullNoticeId,
      title: title,
      channelName: l10n.activeDownloads,
      percent: percent,
      body: body,
    );
  }
}
