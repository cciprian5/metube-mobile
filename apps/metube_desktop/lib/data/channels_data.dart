import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import 'library_data.dart';

/// What the server says about the channels it follows.
///
/// Null [subscriptions] is not an empty list: it is a MeTube older than
/// subscriptions, and the page says so rather than offering a button that
/// could never work.
class ChannelsState {
  const ChannelsState(this.subscriptions);

  final List<ChannelSubscription>? subscriptions;

  bool get supported => subscriptions != null;

  /// For reading, as on the phone: the ones that need attention first,
  /// then the active ones, the paused ones last, each by name.
  List<ChannelSubscription> get sorted => [...?subscriptions]
    ..sort((a, b) {
      if (a.hasError != b.hasError) return a.hasError ? -1 : 1;
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  ChannelSubscription? byId(String id) =>
      subscriptions?.where((s) => s.id == id).firstOrNull;
}

/// The list, read again on demand. **Not polled**: the server checks on its
/// own schedule, and what it downloads arrives through the history like
/// everything else.
final channelsProvider = FutureProvider<ChannelsState>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return const ChannelsState(null);
  return ChannelsState(await api.fetchSubscriptions());
});

/// The intervals offered, in minutes, as on the phone: nothing under half
/// an hour, since a feed fetched every minute is fetched 1,440 times a day
/// for a video that comes weekly.
const channelIntervals = <int>[30, 60, 180, 360, 720, 1440];

/// The offered interval nearest to [minutes]: a server set up elsewhere
/// may hold any number, and the choice must not show empty.
int nearestChannelInterval(int minutes) => channelIntervals.contains(minutes)
    ? minutes
    : channelIntervals.reduce(
        (a, b) => (a - minutes).abs() <= (b - minutes).abs() ? a : b,
      );

/// What can be done to the followed channels. Each action **reads the list
/// again** rather than editing a copy: the server owns this state, may
/// refuse a change, and a check changes fields nobody sent.
class ChannelsController {
  const ChannelsController(this._ref);

  final Ref _ref;

  MeTubeApi? get _api => _ref.read(apiClientProvider);

  /// Returns the channel's own title as the server resolved it, so the
  /// notice names what was followed rather than echoing the link.
  ///
  /// The phones' "compatible video" preset is not sent: it exists for
  /// phone decoders, and this player plays every format the server makes.
  Future<String?> follow(
    String url, {
    required Quality quality,
    required int checkIntervalMinutes,
    String? titleRegex,
    bool ownFolder = false,
    String folder = '',
  }) async {
    final api = _api;
    if (api == null) throw const NoApiException();
    final named = ownFolder ? ServerPath.cleanFolder(folder) : '';
    final created = await api.subscribe(
      url,
      quality,
      checkIntervalMinutes: checkIntervalMinutes,
      titleRegex: titleRegex,
      folder: named.isEmpty ? null : named,
    );
    // **An empty name means the channel's own**, which only the server
    // knows once it has resolved the link. Set straight after: nothing is
    // downloaded in between, since following marks what is there as seen.
    if (ownFolder && named.isEmpty && created != null) {
      final fromChannel = channelFolderName(created.name);
      if (fromChannel.isNotEmpty) {
        await api.updateSubscription(created.id, folder: fromChannel);
      }
    }
    _reload();
    return created?.name;
  }

  Future<void> setEnabled(ChannelSubscription sub, bool enabled) async {
    await _api?.updateSubscription(sub.id, enabled: enabled);
    _reload();
  }

  /// [folder] null leaves it as it is; empty sends new clips to the top.
  Future<void> edit(
    ChannelSubscription sub, {
    required String name,
    required int checkIntervalMinutes,
    required String titleRegex,
    String? folder,
  }) async {
    await _api?.updateSubscription(
      sub.id,
      name: name == sub.name ? null : name,
      checkIntervalMinutes: checkIntervalMinutes == sub.checkIntervalMinutes
          ? null
          : checkIntervalMinutes,
      titleRegex: titleRegex.isEmpty ? null : titleRegex,
      // An emptied field is a deletion, and the server reads only the
      // keys it is sent.
      clearTitleRegex: titleRegex.isEmpty && sub.titleRegex != null,
      folder: folder,
    );
    _reload();
  }

  Future<void> unfollow(ChannelSubscription sub) async {
    await _api?.deleteSubscriptions([sub.id]);
    _reload();
  }

  /// A check takes as long as yt-dlp takes to walk the channel; the list
  /// is read again when it ends, **and the library with it**, or a check
  /// that found something looks like one that did nothing.
  Future<void> checkNow({ChannelSubscription? only}) async {
    await _api?.checkSubscriptions(ids: only == null ? null : [only.id]);
    _reload();
    _ref.invalidate(historyProvider);
  }

  void _reload() => _ref.invalidate(channelsProvider);
}

final channelsControllerProvider = Provider(ChannelsController.new);
