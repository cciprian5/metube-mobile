import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'folder_picker.dart';

/// **"Save in its own folder"** for a followed channel, as on the phone:
/// off unless the subscription already has one; when on, the folder is
/// named after the channel by default, or picked among the server's, or
/// made new. A choice, not a rule: most people never open the server's
/// folders.
class OwnFolderField extends StatelessWidget {
  const OwnFolderField({
    super.key,
    required this.on,
    required this.choice,
    required this.audio,
    required this.onToggle,
    required this.onPicked,
  });

  final bool on;
  final FolderChoice choice;

  /// The channel downloads sound, whose folders the server keeps apart.
  final bool audio;
  final ValueChanged<bool> onToggle;
  final ValueChanged<FolderChoice> onPicked;

  Future<void> _pick(BuildContext context) async {
    // The link field would take the focus back as the picker closes.
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showFolderPicker(
      context,
      audio: audio,
      current: choice,
      // "No folder" is the switch turned off, so it is not offered twice.
      offerTop: false,
      offerChannelName: true,
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.ownFolder,
                    style: text.bodySmall?.copyWith(color: p.ink),
                  ),
                  Text(
                    l.ownFolderNote,
                    style: text.labelSmall?.copyWith(color: p.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MTSpace.sm),
            MTSwitch(
              value: on,
              semanticLabel: l.ownFolder,
              onChanged: onToggle,
            ),
          ],
        ),
        if (on) ...[
          const SizedBox(height: MTSpace.sm),
          FolderLine(
            value: folderLabel(l, choice),
            onPick: () => unawaited(_pick(context)),
          ),
        ],
      ],
    );
  }
}
