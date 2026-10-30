import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import 'library_data.dart';

/// How soon the server is asked again: often while it is downloading
/// something (a clip sent from the phone shows the moment it is done),
/// less when idle, and rarely with the window out of sight, where only the
/// arrival notices need it. The list is a few hundred kilobytes that the
/// server does not compress, so an address outside the house is asked
/// less: that is a phone's data or a tunnel's quota.
const libraryWatchBusy = Duration(seconds: 5);
const libraryWatchBusyAway = Duration(seconds: 30);
const libraryWatchIdle = Duration(seconds: 20);
const libraryWatchIdleAway = Duration(minutes: 2);
const libraryWatchHidden = Duration(minutes: 5);

/// A look sooner than this after the last one is skipped, so clicking
/// back and forth between windows does not ask the server each time.
const libraryWatchMinGap = Duration(seconds: 3);

Duration libraryWatchEvery({
  required bool shown,
  required bool nearby,
  required bool busy,
}) {
  if (!shown) return libraryWatchHidden;
  if (busy) return nearby ? libraryWatchBusy : libraryWatchBusyAway;
  return nearby ? libraryWatchIdle : libraryWatchIdleAway;
}

/// Whether [baseUrl] points inside this network: a private or loopback
/// address, or a name with no dots or a home suffix ("nas", "nas.local").
bool isNearbyAddress(String baseUrl) {
  final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  if (host == 'localhost' || !host.contains('.') && !host.contains(':')) {
    return true;
  }
  if (host.endsWith('.local') ||
      host.endsWith('.lan') ||
      host.endsWith('.home.arpa')) {
    return true;
  }
  if (host.contains(':')) {
    return host == '::1' ||
        host.startsWith('fe80') ||
        host.startsWith('fc') ||
        host.startsWith('fd');
  }
  final parts = host.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null)) return false;
  final (a, b) = (parts[0]!, parts[1]!);
  return a == 10 ||
      a == 127 ||
      (a == 192 && b == 168) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 169 && b == 254);
}

/// What a look compares: every item's id, state and file, so a new clip,
/// a finished one, a renamed or a deleted one all count as a change, and
/// nothing else does.
String historyPrint(HistoryResponse history) => [
  for (final list in [history.done, history.queue, history.pending]) ...[
    '|',
    for (final item in list) '${item.id}:${item.status.name}:${item.filename}',
  ],
].join(',');

/// Hands a list the watcher already fetched to [historyProvider], so a
/// change costs one request and not two.
class HistoryHandoff {
  HistoryResponse? _next;

  void give(HistoryResponse history) => _next = history;

  HistoryResponse? take() {
    final next = _next;
    _next = null;
    return next;
  }
}

final historyHandoffProvider = Provider((ref) => HistoryHandoff());

/// **The library keeps up with the server by itself**, watched by the
/// shell: what the phone, the server's own page or a followed channel adds
/// shows here without a button, and the arrival notices hear of it too.
/// It asks right away when the window comes back to the front, then at
/// [libraryWatchEvery]; the library is rebuilt only when the list changed.
final libraryWatchProvider = Provider<void>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return;
  final nearby = isNearbyAddress(api.config.baseUrl);
  final initial = WidgetsBinding.instance.lifecycleState;
  var shown =
      initial == null ||
      initial == AppLifecycleState.resumed ||
      initial == AppLifecycleState.inactive;
  var busy = false;
  var looking = false;
  var disposed = false;
  DateTime? last;
  Timer? next;

  late void Function() plan;
  Future<void> look() async {
    if (looking || disposed) return;
    looking = true;
    try {
      final fresh = (await api.fetchHistory()).withoutCaptions();
      if (disposed) return;
      busy = fresh.queue.isNotEmpty || fresh.pending.isNotEmpty;
      final current = ref.read(historyProvider).valueOrNull;
      if (current == null || historyPrint(current) != historyPrint(fresh)) {
        ref.read(historyHandoffProvider).give(fresh);
        ref.invalidate(historyProvider);
      }
    } on Exception {
      // A server out of reach or refusing: the page already says so, and
      // the next look tries again.
    } finally {
      looking = false;
      last = DateTime.now();
      if (!disposed) plan();
    }
  }

  plan = () {
    next?.cancel();
    next = Timer(
      libraryWatchEvery(shown: shown, nearby: nearby, busy: busy),
      () => unawaited(look()),
    );
  };

  final lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      shown =
          state == AppLifecycleState.resumed ||
          state == AppLifecycleState.inactive;
      final recent =
          last != null && DateTime.now().difference(last!) < libraryWatchMinGap;
      if (state == AppLifecycleState.resumed && !recent) {
        unawaited(look());
      } else {
        plan();
      }
    },
  );
  plan();
  ref.onDispose(() {
    disposed = true;
    next?.cancel();
    lifecycle.dispose();
  });
});
