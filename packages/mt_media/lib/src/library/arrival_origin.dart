import 'package:mt_core/mt_core.dart';

import 'channel_match.dart';

/// Where a clip that turned up on the server came from, as far as can be
/// known. `/history` does not say, and `/subscriptions` does not list what
/// each one fetched, so anything another device or the web page queued looks
/// the same as what a followed channel brought.
enum ArrivalOrigin {
  /// A channel the user follows posted it.
  followed,

  /// Nothing rules a followed channel out, and nothing confirms one.
  unknown,

  /// No followed channel could have brought it.
  notFollowed,
}

/// Who posted a clip, from its public address; null when that cannot be
/// learned (a site with no public answer, or no network).
typedef ClipAuthorLookup =
    Future<({String? name, String? url})?> Function(String url);

/// The origin of one clip. [uploader] is what the server said, when it did.
Future<ArrivalOrigin> arrivalOrigin(
  String url, {
  String? uploader,
  required List<ChannelSubscription> following,
  required ClipAuthorLookup author,
}) async {
  final platform = MediaPlatform.detect(url);
  final samePlatform = [
    for (final sub in following)
      if (sub.enabled && MediaPlatform.detect(sub.url) == platform) sub,
  ];
  if (samePlatform.isEmpty) return ArrivalOrigin.notFollowed;

  bool names(String? name) =>
      name != null &&
      name.trim().isNotEmpty &&
      samePlatform.any((sub) => channelKey(sub.name) == channelKey(name));
  if (names(uploader)) return ArrivalOrigin.followed;

  final found = await author(url);
  if (found == null) return ArrivalOrigin.unknown;
  final address = _channelAddress(found.url);
  final sameAddress =
      address != null &&
      samePlatform.any((sub) => _channelAddress(sub.url) == address);
  if (sameAddress || names(found.name)) return ArrivalOrigin.followed;
  // A playlist holds other channels' clips, so another author proves nothing.
  return samePlatform.any((sub) => PlaylistDetector.isPlaylist(sub.url))
      ? ArrivalOrigin.unknown
      : ArrivalOrigin.notFollowed;
}

/// The part of a channel's address that names it, whatever tab follows and
/// whichever host it was written with; null for anything else.
String? _channelAddress(String? url) {
  final uri = url == null ? null : Uri.tryParse(url.trim());
  if (uri == null) return null;
  final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  final first = parts.first.toLowerCase();
  if (const {'channel', 'c', 'user'}.contains(first)) {
    return parts.length < 2 ? null : '$first/${parts[1].toLowerCase()}';
  }
  return first;
}

/// The arrivals worth a notice: those a followed channel brought, and those
/// that could not be told apart from one.
typedef SortedArrivals<T> = ({List<T> followed, List<T> unknown});

/// [arrivals] by origin, dropping what no followed channel could have
/// brought. A long absence can leave hundreds, so past [maxLookups] they go
/// unasked and count as unknown.
Future<SortedArrivals<T>> sortArrivals<T>(
  List<T> arrivals, {
  required String Function(T) urlOf,
  String? Function(T)? uploaderOf,
  required List<ChannelSubscription> following,
  required ClipAuthorLookup author,
  int maxLookups = 20,
}) async {
  var asked = 0;
  Future<({String? name, String? url})?> limited(String url) async =>
      asked++ < maxLookups ? author(url) : null;
  final origins = await Future.wait([
    for (final item in arrivals)
      arrivalOrigin(
        urlOf(item),
        uploader: uploaderOf?.call(item),
        following: following,
        author: limited,
      ),
  ]);
  return (
    followed: [
      for (final (i, item) in arrivals.indexed)
        if (origins[i] == ArrivalOrigin.followed) item,
    ],
    unknown: [
      for (final (i, item) in arrivals.indexed)
        if (origins[i] == ArrivalOrigin.unknown) item,
    ],
  );
}

/// The author of a clip from the same public answer the add sheet previews,
/// which carries no credentials of the user's server.
ClipAuthorLookup clipAuthorFrom(ClipPreviewResolver resolver) => (url) async {
  final preview = await resolver.resolve(url);
  return preview == null
      ? null
      : (name: preview.author, url: preview.authorUrl);
};

/// **What this device sent and the server has not finished**, across runs.
///
/// A clip added here and finished while the app was closed would otherwise
/// be taken for something that arrived by itself. Only what is still under
/// way is kept, so the list stays short.
class UnfinishedSends {
  UnfinishedSends({
    required this.store,
    required this.mutex,
    required this.key,
  });

  final KeyValueStore store;
  final PrefsMutex mutex;
  final String key;
  Set<String>? _kept;

  Future<Set<String>> _read() async =>
      _kept ??= (await store.getStringList(key) ?? const <String>[]).toSet();

  /// Everything still recorded as sent from here.
  Future<Set<String>> all() async => {...await _read()};

  /// Records [url], unless the server had already finished it.
  Future<void> note(String url, {required bool finished}) async {
    if (finished || !(await _read()).add(url)) return;
    await _write();
  }

  /// Forgets what is now in [finished], which reports it from here on.
  Future<void> settle(Iterable<String> finished) async {
    final kept = await _read();
    final before = kept.length;
    kept.removeAll(finished);
    if (kept.length != before) await _write();
  }

  Future<void> _write() => mutex.run(
    () async => store.setStringList(key, (await _read()).toList()),
  );
}
