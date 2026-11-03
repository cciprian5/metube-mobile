import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import 'library_data.dart';

/// The newest MeTube release; main asks GitHub, so a test never does.
final metubeLatestProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () async => null,
);

/// What the server runs, and whether a newer MeTube is out.
class ServerRelease {
  const ServerRelease({this.version, this.latest});

  final ServerVersion? version;

  /// The newest tag on MeTube's repository, when it was worth asking.
  final String? latest;

  /// Only ever true for two real dated versions: telling someone their fine
  /// server is out of date is worse than saying nothing.
  bool get isOutdated =>
      latest != null && (version?.isOlderThan(latest!) ?? false);
}

/// Read once per run and per server, never polled: the version is a single
/// request, and GitHub is asked only when the answer can be compared.
final serverReleaseProvider = FutureProvider<ServerRelease?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final version = await api.fetchVersion();
  final latest = version != null && version.isKnown
      ? await ref.read(metubeLatestProvider)()
      : null;
  return ServerRelease(version: version, latest: latest);
});
