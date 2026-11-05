import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/open_web_link.dart';

import '../../data/channels_data.dart';
import '../../router.dart';
import '../../shell/context_menu.dart';
import '../../shell/error_text.dart';
import 'follow_dialog.dart';

/// Runs [action] and says why if the server refused it.
Future<void> _guarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on Object catch (e) {
    if (!context.mounted) return;
    showMTNotice(
      context,
      message: errorText(context.mtl, e),
      kind: MTNoticeKind.failed,
    );
  }
}

/// Checks one channel, or all of them. Said at once, since a check lasts
/// as long as the server takes to walk the channel.
Future<void> checkChannels(
  BuildContext context,
  WidgetRef ref, {
  ChannelSubscription? only,
}) {
  showMTNotice(context, message: context.mtl.checkQueued);
  return _guarded(
    context,
    () => ref.read(channelsControllerProvider).checkNow(only: only),
  );
}

/// Pausing is not confirmed: it is undone by the same switch.
Future<void> setChannelEnabled(
  BuildContext context,
  WidgetRef ref,
  ChannelSubscription sub,
  bool enabled,
) => _guarded(
  context,
  () => ref.read(channelsControllerProvider).setEnabled(sub, enabled),
);

/// Unfollowing is confirmed: the server forgets what it has seen, and a
/// later follow fetches nothing already on the channel.
Future<bool> unfollowChannel(
  BuildContext context,
  WidgetRef ref,
  ChannelSubscription sub,
) async {
  final l = context.mtl;
  final sure = await showMTConfirm(
    context,
    title: l.unfollowConfirm(mtName(sub.name)),
    message: l.unfollowConfirmBody,
    confirmLabel: l.unfollow,
    cancelLabel: l.cancel,
    destructive: true,
  );
  if (!sure || !context.mounted) return false;
  var done = false;
  await _guarded(context, () async {
    await ref.read(channelsControllerProvider).unfollow(sub);
    done = true;
  });
  return done;
}

/// The channel on its own site, in the browser.
Future<void> openChannelSite(ChannelSubscription sub) => openWebLink(sub.url);

enum _ChannelChoice { open, check, edit, unfollow }

/// A channel's right-click menu, in the phone's order, unfollowing last.
Future<void> showChannelMenu(
  BuildContext context,
  WidgetRef ref,
  ChannelSubscription sub,
  Offset at,
) async {
  final l = context.mtl;
  final router = GoRouter.of(context);
  final choice = await showEmberMenu(context, at, [
    EmberMenuEntry(_ChannelChoice.open, MTIcons.external, l.openChannel),
    EmberMenuEntry(_ChannelChoice.check, null, l.checkNow),
    EmberMenuEntry(_ChannelChoice.edit, null, l.editSubscription),
    const EmberMenuEntry.divider(),
    EmberMenuEntry(
      _ChannelChoice.unfollow,
      MTIcons.trash,
      l.unfollow,
      danger: true,
    ),
  ]);
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _ChannelChoice.open:
      await openChannelSite(sub);
    case _ChannelChoice.check:
      await checkChannels(context, ref, only: sub);
    case _ChannelChoice.edit:
      await showFollowDialog(context, editing: sub);
    case _ChannelChoice.unfollow:
      if (await unfollowChannel(context, ref, sub)) {
        router.go(EmberRoutes.channels);
      }
  }
}
