import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show PlaybackPositionStore;

import '../../data/channels_data.dart';
import '../../data/library_data.dart';
import '../../di.dart';

/// The one spelling a channel's name is compared in.
///
/// A subscription is named after what yt-dlp resolved, which for a
/// channel's page is the tab ("Eric Tech - Videos") and for its uploads
/// playlist "Uploads from Eric Tech"; a clip names its uploader alone. So
/// the tab and the prefix go, then case and spacing.
String channelKey(String name) {
  var key = name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  key = key.replaceFirst(RegExp(r'^uploads from '), '');
  key = key.replaceFirst(
    RegExp(r' - (videos|shorts|live|streams|podcasts|releases|playlists)$'),
    '',
  );
  return key.trim();
}

/// What the library holds from one channel, worked out on this computer.
class ChannelStats {
  const ChannelStats({required this.items, required this.unwatched});

  /// Newest first.
  final List<LibraryItem> items;

  /// Never started on this computer.
  final int unwatched;

  int get count => items.length;

  DateTime? get lastArrival => items.firstOrNull?.timestamp;

  /// The covers of the last three, for the channel's row.
  List<String?> get covers => [for (final i in items.take(3)) i.thumbnail];
}

/// A channel the library has clips from that no subscription follows.
class LibraryChannel {
  const LibraryChannel({required this.name, required this.count});

  final String name;
  final int count;
}

class ChannelMatch {
  const ChannelMatch({
    required this.stats,
    required this.unfollowed,
    required this.namesChannels,
  });

  /// By subscription id, **only for channels with clips here**: a channel
  /// nothing matches has no entry, so its row shows the server's facts
  /// alone rather than a "0 in your library" that may be false.
  final Map<String, ChannelStats> stats;

  /// Most clips first.
  final List<LibraryChannel> unfollowed;

  /// Whether any clip names its channel at all. Some servers' histories
  /// carry no uploader, and nothing can be matched there.
  final bool namesChannels;
}

/// Matches the library to the followed channels, by name and by folder.
final channelMatchProvider = FutureProvider<ChannelMatch>((ref) async {
  final items = await ref.watch(libraryItemsProvider.future);
  final subs = (await ref.watch(channelsProvider.future)).subscriptions ?? [];
  final positions = PlaybackPositionStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  );
  return matchChannels(items, {
    for (final s in subs) s.id: (name: s.name, folder: s.folder),
  }, started: (url) async => await positions.stampOf(url) != null);
});

/// A followed channel as matching needs it.
typedef FollowedChannel = ({String name, String? folder});

/// The matching itself, apart from storage: [subscriptions] by id, and
/// [started] says whether a clip was ever played here.
///
/// A channel's clips are those whose uploader is its name, **and those in
/// its own folder** when it saves into one: the server's history may name
/// no uploader at all, but it always says where each file went.
Future<ChannelMatch> matchChannels(
  List<LibraryItem> items,
  Map<String, FollowedChannel> subscriptions, {
  required Future<bool> Function(String canonicalUrl) started,
}) async {
  final byKey = <String, List<LibraryItem>>{};
  final spelled = <String, String>{};
  for (final item in items) {
    final who = item.uploader?.trim();
    if (who == null || who.isEmpty) continue;
    final key = channelKey(who);
    (byKey[key] ??= []).add(item);
    spelled.putIfAbsent(key, () => who);
  }
  final followed = <String>{};
  final stats = <String, ChannelStats>{};
  for (final MapEntry(key: id, value: sub) in subscriptions.entries) {
    final key = channelKey(sub.name);
    followed.add(key);
    final folder = sub.folder;
    final seen = <String>{};
    final mine = [
      for (final item in [
        ...?byKey[key],
        if (folder != null && folder.isNotEmpty)
          for (final item in items)
            if (item.isIn(folder)) item,
      ])
        if (seen.add(item.canonicalUrl)) item,
    ];
    if (mine.isEmpty) continue;
    mine.sort(
      (a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)),
    );
    var unwatched = 0;
    for (final item in mine) {
      if (!await started(item.canonicalUrl)) unwatched++;
    }
    stats[id] = ChannelStats(items: mine, unwatched: unwatched);
  }
  final unfollowed = [
    for (final MapEntry(:key, :value) in byKey.entries)
      if (!followed.contains(key))
        LibraryChannel(name: spelled[key]!, count: value.length),
  ]..sort((a, b) => b.count.compareTo(a.count));
  return ChannelMatch(
    stats: stats,
    unfollowed: unfollowed,
    namesChannels: byKey.isNotEmpty,
  );
}
