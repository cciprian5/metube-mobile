import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/server_release.dart';
import 'simple_panes.dart';

/// What the server runs, as the phone's server card says it, and whether a
/// newer MeTube is out. It only informs: the server is updated where it is
/// hosted.
class ServerVersionLine extends ConsumerWidget {
  const ServerVersionLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(serverReleaseProvider).valueOrNull;
    if (release == null) return const SizedBox.shrink();
    final l = context.mtl;
    final version = release.version;
    return SettingLine(
      title: l.desktopServerVersion,
      value: [
        switch (version) {
          final ServerVersion v when v.isKnown => l.serverVersionLabel(
            v.version,
          ),
          _ => l.serverVersionUnknown,
        },
        if (version?.ytDlp case final ytDlp? when ytDlp.isNotEmpty)
          mtLtrRun('yt-dlp $ytDlp'),
      ].join(' · '),
      hint: release.isOutdated
          ? l.serverVersionOutdated(release.latest!)
          : null,
    );
  }
}
