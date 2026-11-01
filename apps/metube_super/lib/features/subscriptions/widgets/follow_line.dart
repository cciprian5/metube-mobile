import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show PlaylistItem;
import 'package:mt_ui/mt_ui.dart';

import '../../home/link_preview_view.dart';
import '../subscription_sheet.dart';
import '../subscriptions_providers.dart';

/// Who made a YouTube clip, asked of YouTube's public oEmbed, once a
/// session per clip. **The server's history names no channel** (measured
/// on the owner's server, 2026-11-01), and oEmbed gives the channel's own
/// address, which is what following it needs.
final clipChannelProvider = FutureProvider.family<ClipPreview?, String>(
  (ref, url) => ref.read(linkPreviewResolverProvider).resolve(url),
);

/// The channel under a YouTube clip's title in the video player, with
/// "Follow", or "Following" when the server already follows it. Follow
/// opens the follow sheet with the link filled in; nothing is sent until
/// the user confirms there. Nothing shows for other sites, offline, or
/// when YouTube does not answer within the preview's time.
class FollowLine extends ConsumerWidget {
  const FollowLine({super.key, required this.item});

  final PlaylistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!MediaPlatform.detect(item.canonicalUrl).isYouTube) {
      return const SizedBox.shrink();
    }
    final channel = ref.watch(clipChannelProvider(item.canonicalUrl));
    final author = channel.valueOrNull?.author;
    final url = channel.valueOrNull?.authorUrl;
    if (author == null || url == null) return const SizedBox.shrink();
    final subs =
        ref.watch(subscriptionsProvider).valueOrNull?.subscriptions ?? [];
    final following = subs.any(
      (s) =>
          sameChannel(s.url, url) || channelKey(s.name) == channelKey(author),
    );
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: MTSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: mtTextDirectionOf(
                author,
                Directionality.of(context),
              ),
              style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: MTSpace.sm),
          if (following)
            Text(l10n.followingChannel, style: text.labelMedium)
          else
            OutlinedButton(
              onPressed: () =>
                  showSubscriptionSheet(context, ref, url: url, name: author),
              child: Text(l10n.follow),
            ),
        ],
      ),
    );
  }
}

/// Whether two channel addresses are the same, whatever their case or a
/// trailing slash.
bool sameChannel(String a, String b) {
  String plain(String url) =>
      url.trim().toLowerCase().replaceFirst(RegExp(r'/+$'), '');
  return plain(a) == plain(b);
}
