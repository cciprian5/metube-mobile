import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import 'downloads_panel.dart';

/// The downloads button above the content, with the count of what is
/// under way on its corner; it opens [DownloadsPanel].
class DownloadsButton extends ConsumerWidget {
  const DownloadsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final active = ref.watch(activeDownloadsProvider);
    final label = active > 0
        ? '${l.desktopDownloads} · ${l.activeDownloadsCount(active)}'
        : l.desktopDownloads;
    return MTShortcutTooltip(
      message: label,
      child: IconButton(
        onPressed: () => unawaited(showDownloadsPanel(context)),
        icon: Badge(
          isLabelVisible: active > 0,
          backgroundColor: p.accent,
          textColor: p.onAccent,
          label: Text('$active'),
          child: MTIcon(
            MTIcons.download,
            size: MTSpace.lg,
            color: active > 0 ? p.accentInk : p.ink2,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}
