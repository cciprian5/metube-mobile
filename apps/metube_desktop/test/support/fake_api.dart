import 'dart:io';

import 'package:mt_core/mt_core.dart';

/// The real client for a server that is never reached: only deleting is
/// replaced, recorded instead of sent.
class FakeApi extends MeTubeApiClient {
  FakeApi(ServerConfig config) : super(config: config);

  final List<List<String>> deleted = [];

  /// What the server answers a delete with instead; null deletes.
  Object? deleteError;

  @override
  Future<void> delete(
    List<String> canonicalUrls, {
    String where = 'done',
  }) async {
    if (deleteError case final error?) throw error;
    deleted.add(canonicalUrls);
  }

  /// The server's folders, as its socket would list them; null is a
  /// server too old to say.
  ServerFolders? folders = const ServerFolders();

  /// The files the server would send, by their server path; asking for
  /// any other fails as a dropped connection would.
  final Map<String, List<int>> files = {};

  /// What was pulled, in order.
  final List<String> pulled = [];

  // The cancel token's type is the network client's own; left to inference
  // so the tests need not import it.
  @override
  Future<void> downloadTo(
    String serverFilename,
    String savePath, {
    void Function(int received, int total)? onProgress,
    cancelToken,
  }) async {
    pulled.add(serverFilename);
    final bytes = files[serverFilename];
    if (bytes == null) throw const NetworkException('not on the server');
    onProgress?.call(bytes.length ~/ 2, bytes.length);
    await File(savePath).writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<ServerFolders?> fetchFolders({Duration? timeout}) async => folders;

  /// Whether the server holds cookies; null is a server too old to say.
  bool? cookies = false;

  /// Each cookies file sent, by name and contents.
  final List<(String, List<int>)> cookieUploads = [];

  @override
  Future<bool?> hasCookies({Duration? timeout}) async => cookies;

  @override
  Future<void> uploadCookies(
    List<int> bytes, {
    String filename = 'cookies.txt',
  }) async {
    cookieUploads.add((filename, bytes));
    cookies = true;
  }

  @override
  Future<void> deleteCookies() async => cookies = false;

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
