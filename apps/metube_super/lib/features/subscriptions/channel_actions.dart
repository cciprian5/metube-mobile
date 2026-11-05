import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../shared/error_text.dart';
import 'subscriptions_providers.dart';

// What can be done to a followed channel, from its list and from its own
// page alike.

/// A check walks the channel with yt-dlp, which is slow enough that the
/// user is told it started rather than left watching a spinner.
void checkSubscriptions(
  BuildContext context,
  WidgetRef ref, {
  ChannelSubscription? only,
}) {
  showMTSnack(context, context.mtl.checkQueued, type: MTSnackType.info);
  runSubscriptionAction(context, ref, (c) => c.checkNow(only: only));
}

/// **Unfollowing is confirmed and pausing is not**, because only one of
/// them destroys something: the server's memory of what it has already
/// seen, which cannot be rebuilt. True when the user confirmed.
Future<bool> confirmUnfollow(
  BuildContext context,
  WidgetRef ref,
  ChannelSubscription sub,
) async {
  final l10n = context.mtl;
  final confirmed = await showMTDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.unfollowConfirm(mtName(sub.name))),
      content: Text(l10n.unfollowConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.unfollow),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  runSubscriptionAction(context, ref, (c) => c.unfollow(sub));
  return true;
}

/// Every action goes through here so a server that refuses says why,
/// instead of leaving a switch that flicks back with no explanation.
void runSubscriptionAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(SubscriptionsController) action,
) {
  final l10n = context.mtl;
  // Captured now: the action outlives the frame, and reading the
  // messenger from a dead context afterwards throws.
  final messenger = ScaffoldMessenger.of(context);
  action(ref.read(subscriptionsControllerProvider)).catchError((Object e) {
    showMTSnackOn(messenger, errorText(l10n, e), type: MTSnackType.error);
  });
}
