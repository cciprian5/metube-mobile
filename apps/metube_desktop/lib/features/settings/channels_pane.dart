import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/channels_data.dart';
import '../../data/choices_data.dart';
import '../../router.dart';
import 'simple_panes.dart';

/// Subscriptions: the channels themselves live in Channels in the
/// sidebar; here are how many there are and the one setting they have.
class SubscriptionsPane extends ConsumerWidget {
  const SubscriptionsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final channels = ref.watch(channelsProvider).valueOrNull;
    final count = channels?.subscriptions?.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingLine(
          title: switch (channels) {
            null => l.subscriptionsSubtitle,
            ChannelsState(supported: false) => l.subscriptionsUnsupported,
            _ => l.settingsValueChannels(count ?? 0),
          },
          hint: l.subscriptionsSubtitle,
          trailing: MTLinkButton(
            label: l.desktopOpenChannels,
            onPressed: () => context.go(EmberRoutes.channels),
          ),
        ),
        SwitchLine(
          title: l.notifyArrivals,
          hint: l.desktopNotifyArrivalsHint,
          value: ref.watch(notifyArrivalsProvider),
          onChanged: (on) =>
              unawaited(ref.read(notifyArrivalsProvider.notifier).set(on)),
        ),
      ],
    );
  }
}
