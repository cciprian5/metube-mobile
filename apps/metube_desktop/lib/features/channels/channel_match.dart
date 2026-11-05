import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show PlaybackPositionStore;

import '../../data/channels_data.dart';
import '../../data/library_data.dart';
import '../../di.dart';

// The matching itself is shared with the phone app.
export 'package:mt_media/library.dart'
    show
        ChannelMatch,
        ChannelStats,
        FollowedChannel,
        LibraryChannel,
        channelKey,
        matchChannels;

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
