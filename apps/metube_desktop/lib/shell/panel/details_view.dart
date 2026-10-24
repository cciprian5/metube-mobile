import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../features/library/platform_label.dart';

/// What is known about the playing clip, with its link one click from the
/// clipboard (a phone hides this in a sheet; the panel has the room).
class DetailsView extends StatelessWidget {
  const DetailsView({super.key, required this.item});

  final PlaylistItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final folder = switch (item.serverFilename) {
      final name? => ServerPath.folderOf(name),
      null => '',
    };
    final rows = [
      if (item.uploader case final who?) (l.desktopChannel, who),
      if (folder.isNotEmpty) (l.folder, mtName(folder)),
      (l.platform, platformLabel(l, MediaPlatform.detect(item.canonicalUrl))),
      if (item.duration case final length?)
        (l.columnLength, mtLtrRun(mtFormatDuration(length))),
      (
        l.source,
        item.localPath != null ? l.playingFromDevice : l.streamingFromServer,
      ),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in rows) _Row(label: label, value: value),
          const SizedBox(height: MTSpace.md),
          _LinkRow(url: item.canonicalUrl),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MTSpace.xxl * 3,
            child: Text(label, style: text.labelSmall?.copyWith(color: p.ink3)),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: mtTextDirectionOf(
                value,
                Directionality.of(context),
              ),
              style: text.bodySmall?.copyWith(color: p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // An address reads left to right in any language.
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(
            url,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: p.ink2),
          ),
        ),
        const SizedBox(height: MTSpace.xs),
        MTLinkButton(
          label: l.desktopCopyLink,
          icon: MTIcons.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (!context.mounted) return;
            showMTNotice(context, message: l.desktopLinkCopied);
          },
        ),
      ],
    );
  }
}
