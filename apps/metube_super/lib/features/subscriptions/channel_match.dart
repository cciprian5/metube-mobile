import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import 'subscriptions_providers.dart';

/// What the library holds from each followed channel, matched by name and
/// by the channel's own folder (the matching itself is shared with the
/// Windows app). A server whose history names no uploader still says where
/// each file went, so a channel that saves into a folder is matched there.
final channelMatchProvider = FutureProvider<ChannelMatch>((ref) async {
  final items = await ref.watch(libraryItemsProvider.future);
  final subs = (await ref.watch(subscriptionsProvider.future)).subscriptions;
  final positions = ref.watch(playbackPositionsProvider);
  return matchChannels(items, {
    for (final s in subs ?? const <ChannelSubscription>[])
      s.id: (name: s.name, folder: s.folder),
  }, started: (url) async => await positions.stampOf(url) != null);
});
