import 'package:mt_core/mt_core.dart';

/// The real client for a server that is never reached: only deleting is
/// replaced, recorded instead of sent.
class FakeApi extends MeTubeApiClient {
  FakeApi(ServerConfig config) : super(config: config);

  final List<List<String>> deleted = [];

  @override
  Future<void> delete(
    List<String> canonicalUrls, {
    String where = 'done',
  }) async => deleted.add(canonicalUrls);

  /// The server's folders, as its socket would list them; null is a
  /// server too old to say.
  ServerFolders? folders = const ServerFolders();

  @override
  Future<ServerFolders?> fetchFolders({Duration? timeout}) async => folders;

  /// The followed channels; null is a server older than subscriptions.
  List<ChannelSubscription>? subscriptions = [];

  /// What was asked of the channels, in order.
  final List<String> channelCalls = [];

  /// Set to make the next follow fail with it.
  Object? followFailure;

  @override
  Future<List<ChannelSubscription>?> fetchSubscriptions({
    Duration? timeout,
  }) async => subscriptions == null ? null : [...subscriptions!];

  @override
  Future<ChannelSubscription?> subscribe(
    String url,
    Quality quality, {
    required int checkIntervalMinutes,
    bool compatibleVideo = false,
    String? titleRegex,
    String? folder,
  }) async {
    channelCalls.add(
      'subscribe $url ${quality.wire} $checkIntervalMinutes '
      '${titleRegex ?? '-'} compat=$compatibleVideo folder=${folder ?? '-'}',
    );
    if (followFailure case final failure?) throw failure;
    final made = ChannelSubscription(
      id: 'new',
      name: 'Field Notes - Videos',
      url: url,
      enabled: true,
      checkIntervalMinutes: checkIntervalMinutes,
      quality: quality.wire,
      titleRegex: titleRegex,
    );
    subscriptions = [...?subscriptions, made];
    return made;
  }

  @override
  Future<void> updateSubscription(
    String id, {
    String? name,
    bool? enabled,
    int? checkIntervalMinutes,
    String? titleRegex,
    bool clearTitleRegex = false,
    String? folder,
  }) async {
    channelCalls.add(
      'update $id name=${name ?? '-'} enabled=${enabled ?? '-'} '
      'every=${checkIntervalMinutes ?? '-'} filter=${titleRegex ?? '-'} '
      'clear=$clearTitleRegex folder=${folder ?? '-'}',
    );
    subscriptions = [
      for (final s in subscriptions ?? <ChannelSubscription>[])
        s.id == id ? s.copyWith(name: name, enabled: enabled) : s,
    ];
  }

  @override
  Future<void> deleteSubscriptions(List<String> ids) async {
    channelCalls.add('delete ${ids.join(',')}');
    subscriptions = [
      for (final s in subscriptions ?? <ChannelSubscription>[])
        if (!ids.contains(s.id)) s,
    ];
  }

  @override
  Future<void> checkSubscriptions({List<String>? ids}) async =>
      channelCalls.add('check ${ids?.join(',') ?? 'all'}');
}
