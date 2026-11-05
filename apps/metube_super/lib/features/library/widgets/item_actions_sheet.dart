import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart' show CancelledException, ImageHeaders;
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_media/library.dart';

import '../../playlists/add_to_playlist_sheet.dart';
import '../../shared/error_report.dart';
import '../../shared/external_player.dart';
import '../../tags/item_tags_sheet.dart';
import '../../transcripts/transcript_openers.dart';
import '../../transcripts/transcripts_state.dart';
import '../../../di.dart';
import '../artwork_view.dart';
import '../device_pulls.dart';
import '../library_actions.dart';
import '../library_providers.dart';
import 'confirm_bulk_delete.dart';
import 'item_details_sheet.dart';
import 'share_sheet.dart';
import '../../shared/open_web_link.dart';

/// The item actions sheet, by state (rule 5). Delete comes last, isolated
/// by a divider and in the error colour, which is a general navigation
/// rule.
void showItemActionsSheet(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item,
) {
  showMTSheet<void>(
    context: context,
    useRootNavigator: true,
    // As tall as its rows, not the default nine sixteenths of the screen,
    // which hid Delete below a scroll once the menu grew a row. It still
    // scrolls on a phone too short for all of them.
    isScrollControlled: true,
    useSafeArea: true,
    // The screen's context, not the sheet's, is passed for opening later
    // sheets: using a closed sheet's context trips the
    // `_dependents.isEmpty`
    // assertion.
    builder: (_) => _ItemActionsSheet(item: item, host: context),
  );
}

class _ItemActionsSheet extends ConsumerWidget {
  const _ItemActionsSheet({required this.item, required this.host});

  final LibraryItem item;

  /// The hosting screen's context, which stays alive after this sheet
  /// closes.
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final actions = ref.read(libraryActionsProvider);
    final saving = ref
        .watch(devicePullsProvider)
        .containsKey(DevicePull.keyOf(PullKind.offline, item.canonicalUrl));
    final clip = MTDialogClip(
      title: mtName(item.title),
      thumbnail: artworkFor(
        item.thumbnail,
        headers: switch (item.thumbnail) {
          final url? => ref.read(apiClientProvider)?.imageHeadersFor(url),
          null => null,
        },
        decodeWidth: 120,
      ),
    );

    Future<void> run(
      Future<void> Function() action, {
      String? successText,
    }) async {
      Navigator.pop(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      try {
        await action();
        if (successText != null && messenger != null && context.mounted) {
          showMTSnack(context, successText, type: MTSnackType.success);
        }
      } on CancelledException {
        // Stopped on purpose; nothing went wrong.
      } catch (e) {
        if (context.mounted) {
          showErrorSnack(context, ref, e, tag: 'library');
        }
      }
    }

    ListTile tile(
      MTIconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      leading: MTIcon(icon, color: color ?? p.ink2),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: color),
      ),
      onTap: onTap,
    );

    // Scrolls when it outgrows the sheet: a sheet stops at nine sixteenths
    // of the screen, and on a short phone the last rows, delete among
    // them, were cut off.
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MTSpace.xl,
                MTSpace.lg,
                MTSpace.xl,
                MTSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MTForeignText(
                      item.title,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // **Favourites from the menu, not an empty heart on every card**
            // (owner's decision 2026-11-01): the card shows a small heart on
            // favourites alone, and the players keep the one-tap heart.
            MTFavoriteTile(
              favorite: item.favorite,
              onTap: () async {
                Navigator.pop(context);
                final added = await actions.toggleFavorite(item.canonicalUrl);
                if (host.mounted) {
                  showMTSnack(
                    host,
                    added ? l10n.addedToFavorites : l10n.removedFromFavorites,
                  );
                }
              },
            ),
            // While its copy runs the row stops it instead: a second tap
            // used to start a second copy of the same clip.
            if (saving)
              tile(MTIcons.close, l10n.cancelSaveToDevice, () {
                Navigator.pop(context);
                ref
                    .read(devicePullsProvider.notifier)
                    .cancel(PullKind.offline, item.canonicalUrl);
              })
            else if (item.onServer && !item.isOffline)
              tile(
                MTIcons.offline,
                l10n.makeOffline,
                () => run(
                  () => actions.makeOffline(item),
                  successText: l10n.madeOffline,
                ),
              ),
            // **Everything from this channel**. The channel is a fact
            // the server already knows, so it needs no tag and no setup: the
            // row only appears when `/history` actually carried a name.
            if (item.uploader case final channel?
                when channel.trim().isNotEmpty)
              tile(
                MTIcons.subscriptions,
                l10n.showChannel(mtName(channel)),
                () {
                  Navigator.pop(context);
                  ref.read(libraryViewProvider.notifier).toggleChannel(channel);
                },
              ),
            tile(MTIcons.info, l10n.details, () {
              Navigator.pop(context);
              showItemDetailsSheet(host, item);
            }),
            // Read without playing. Only for a clip that has one: the index
            // stays empty while transcripts are off.
            if (ref
                    .watch(transcriptIndexProvider)
                    .valueOrNull
                    ?.contains(item.canonicalUrl) ??
                false)
              tile(MTIcons.transcript, l10n.transcript, () {
                Navigator.pop(context);
                showTranscriptSheet(host, item, '');
              }),
            tile(
              MTIcons.share,
              l10n.share,
              () => run(() => shareClip(host, ref, item)),
            ),
            // **The external player is offered for a local copy only**
            // (decision 2026-09-05): a Super server runs without
            // authentication, so handing a streaming URL to another app means
            // open access for anyone who reads its logs. An item with no
            // local copy sees "make available offline" above instead.
            if (item.localPath case final String path)
              tile(
                MTIcons.playback,
                l10n.openInExternalPlayer,
                () => run(() async {
                  final opened = await const ExternalPlayer().open(
                    path,
                    audio: item.isAudio,
                  );
                  if (!opened && host.mounted) {
                    showMTSnack(
                      host,
                      l10n.noExternalPlayer,
                      type: MTSnackType.error,
                    );
                  }
                }),
              ),
            // Every server item has a canonical URL, so the original link
            // is always offered here; Lite offers it only when known.
            tile(MTIcons.external, l10n.openOriginalLink, () {
              Navigator.pop(context);
              openWebLink(item.canonicalUrl);
            }),
            tile(MTIcons.queueAdd, l10n.addToPlaylist, () {
              Navigator.pop(context);
              showAddToPlaylistSheet(host, ref, [item]);
            }),
            tile(MTIcons.tags, l10n.tags, () {
              Navigator.pop(context);
              showItemTagsSheet(host, ref, [item.canonicalUrl]);
            }),
            if (item.isOffline && item.onServer)
              tile(
                MTIcons.phoneOff,
                l10n.removeLocalCopy,
                () => run(
                  () => actions.removeLocalCopy(item),
                  successText: l10n.localCopyRemoved,
                ),
              ),
            const Divider(),
            if (item.onServer)
              tile(
                MTIcons.trash,
                l10n.deleteFromServer,
                () => confirmItemDelete(
                  context,
                  l10n.deleteFromServer,
                  l10n.deleteFromServerConfirm,
                  clip,
                  () => run(
                    () => actions.deleteFromServer([item.canonicalUrl]),
                    successText: l10n.deletedFromServer,
                  ),
                ),
                color: p.err,
              ),
            if (!item.onServer && item.isOffline)
              tile(
                MTIcons.trash,
                l10n.deleteVideo,
                () => confirmItemDelete(
                  context,
                  l10n.deleteVideo,
                  l10n.deleteVideoConfirm(mtName(item.title)),
                  clip,
                  () {
                    run(
                      () => actions.deleteLocalOnly(item),
                      successText: l10n.deletedTitle(mtName(item.title)),
                    );
                  },
                ),
                color: p.err,
              ),
            const SizedBox(height: MTSpace.md),
          ],
        ),
      ),
    );
  }
}
