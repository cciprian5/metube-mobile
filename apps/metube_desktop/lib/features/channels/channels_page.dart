import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/channels_data.dart';
import '../../data/library_data.dart';
import '../../router.dart';
import '../../shell/error_text.dart';
import '../../shell/pill.dart';
import '../../shell/section_header.dart';
import 'channel_commands.dart';
import 'channel_match.dart';
import 'channel_row.dart';
import 'follow_dialog.dart';

/// The followed channels, sorted so the ones needing attention come
/// first and moving to their new place when their state changes; then the
/// channels the library has clips from that nobody follows yet.
class ChannelsPage extends ConsumerWidget {
  const ChannelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final text = Theme.of(context).textTheme;
    final asked = ref.watch(channelsProvider);
    final state = asked.valueOrNull;
    final match = ref.watch(channelMatchProvider).valueOrNull;
    final configured = ref.watch(serverConfigProvider) != null;
    final subs = state?.sorted ?? const <ChannelSubscription>[];
    final supported = state?.supported ?? false;

    Widget fill(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.xxl * 2),
      child: Center(child: child),
    );

    final Widget body;
    if (!configured) {
      body = fill(
        MTEmptyFrame(
          title: l.serverStatusUnconfigured,
          message: l.desktopNoServerMessage,
        ),
      );
    } else if (state == null) {
      body = fill(
        asked.hasError
            ? MTEmptyFrame(
                title: l.failed,
                message: errorText(l, asked.error!),
                actionLabel: l.retry,
                onAction: () => ref.invalidate(channelsProvider),
              )
            : const MTSpinner(),
      );
    } else if (!supported) {
      body = fill(
        MTEmptyFrame(
          title: l.subscriptionsUnsupported,
          message: l.subscriptionsUnsupportedBody,
        ),
      );
    } else if (subs.isEmpty) {
      body = fill(
        MTEmptyFrame(
          title: l.subscriptionsEmpty,
          message: l.subscriptionsEmptyBody,
          actionLabel: l.followChannel,
          onAction: () => unawaited(showFollowDialog(context)),
        ),
      );
    } else {
      body = MTReorderMotion(
        children: [
          for (final sub in subs)
            ChannelRow(
              key: ValueKey(sub.id),
              sub: sub,
              stats: match?.stats[sub.id],
              onOpen: () => context.go(EmberRoutes.channel(sub.id)),
            ),
        ],
      );
    }

    final unfollowed = supported ? match?.unfollowed ?? const [] : const [];
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(
          MTSpace.xl,
          (box.maxWidth - MTBreakpoint.readable) / 2,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, MTSpace.sm, side, MTSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: MTSpace.md,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(l.desktopChannels, style: text.headlineSmall),
                        if (subs.isNotEmpty)
                          Text(
                            l.settingsValueChannels(subs.length),
                            style: text.bodySmall?.copyWith(
                              color: MTThemeX.of(context).palette.ink3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (supported)
                    // The actions wrap under each other before the title
                    // gives way, under a large font.
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: MTSpace.xs,
                        runSpacing: MTSpace.xs,
                        children: [
                          if (subs.isNotEmpty)
                            EmberPill(
                              label: l.desktopCheckAll,
                              selected: false,
                              onTap: () =>
                                  unawaited(checkChannels(context, ref)),
                            ),
                          EmberPill(
                            label: l.followChannel,
                            icon: MTIcons.plus,
                            selected: false,
                            onTap: () => unawaited(showFollowDialog(context)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: MTSpace.lg),
              body,
              if (unfollowed.isNotEmpty) ...[
                const SizedBox(height: MTSpace.xl),
                EmberSectionHeader(title: l.desktopChannelsInLibrary),
                const SizedBox(height: MTSpace.sm),
                for (final channel in unfollowed)
                  _Unfollowed(
                    channel: channel,
                    onFollow: () => unawaited(
                      showFollowDialog(context, name: channel.name),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A channel the library knows and nobody follows: its name, how many of
/// its clips are here, and "Follow".
class _Unfollowed extends StatelessWidget {
  const _Unfollowed({required this.channel, required this.onFollow});

  final LibraryChannel channel;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: mtTextDirectionOf(
                channel.name,
                Directionality.of(context),
              ),
              style: text.bodySmall?.copyWith(color: p.ink),
            ),
          ),
          Text(
            l.desktopInLibrary(channel.count),
            style: text.labelSmall?.copyWith(color: p.ink3),
          ),
          const SizedBox(width: MTSpace.md),
          MTLinkButton(label: l.follow, onPressed: onFollow),
        ],
      ),
    );
  }
}
