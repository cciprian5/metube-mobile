import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../settings/settings_sections.dart';
import '../channel_match.dart';
import '../subscriptions_providers.dart';
import 'channel_row.dart';

/// **"Your channels" in the playlists tab**: the first three followed
/// channels with what the library holds from each, and the way to all of
/// them. A fourth tab for them was turned down (2026-10-31); this keeps
/// them one tap from the lists. Nothing at all on a server that follows
/// none or cannot.
class YourChannelsSection extends ConsumerWidget {
  const YourChannelsSection({super.key});

  /// How many rows the tab shows before "View all".
  static const shown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final subs = ref.watch(subscriptionsProvider).valueOrNull?.sorted ?? [];
    if (subs.isEmpty) return const SizedBox.shrink();
    final match = ref.watch(channelMatchProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: MTSpace.xl),
        MTSectionHeader(
          title: l10n.yourChannels,
          trailing: l10n.yourChannelsHint,
        ),
        for (final sub in subs.take(shown))
          ChannelRow(
            key: ValueKey(sub.id),
            sub: sub,
            stats: match?.stats[sub.id],
            onOpen: () => context.push('/playlists/channel/${sub.id}'),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => context.go(SettingsPane.subscriptions.route),
            child: Text(
              mtMetaLine([
                l10n.viewAll,
                l10n.settingsValueChannels(subs.length),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
