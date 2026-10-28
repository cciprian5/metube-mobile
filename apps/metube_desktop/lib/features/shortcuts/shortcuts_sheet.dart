import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/key_cap.dart';
import '../../shell/shell_metrics.dart';
import '../library/clip_keys.dart';

/// One line of the sheet: the keys as printed on the keyboard, and what
/// they do.
typedef ShortcutLine = ({List<String> keys, String does});

/// Every key the window answers, in four groups. Key names are the
/// keyboard's own and read the same in either language.
List<(String, List<ShortcutLine>)> shortcutGroups(MTLocalizations l) => [
  (
    l.desktopShortcutsPlayback,
    [
      (keys: ['Space'], does: l.desktopKeyPlayPause),
      (keys: ['←', '→'], does: l.desktopKeySeek),
      (keys: ['↑', '↓'], does: l.desktopKeyVolume),
      (keys: ['R'], does: l.desktopKeyRepeat),
      (keys: ['C'], does: l.subtitles),
    ],
  ),
  (
    l.desktopShortcutsClip,
    [
      (keys: [ClipKeys.play], does: l.play),
      (keys: [ClipKeys.playNext], does: l.desktopPlayNext),
      (keys: [ClipKeys.reading], does: l.desktopReadingRoom),
      (keys: [ClipKeys.favorite], does: l.desktopKeyFavorite),
      (keys: [ClipKeys.copyLink], does: l.desktopCopyLink),
      (keys: ['Shift F10'], does: l.desktopKeyMenu),
    ],
  ),
  (
    l.desktopShortcutsWindow,
    [
      (keys: ['F11'], does: l.desktopKeyFullScreen),
      (keys: ['Esc'], does: l.exitFullscreen),
      (keys: ['Ctrl M'], does: l.desktopKeyMini),
      (keys: ['Ctrl +'], does: l.desktopKeyZoomIn),
      (keys: ['Ctrl −'], does: l.desktopKeyZoomOut),
      (keys: ['Ctrl 0'], does: l.desktopKeyZoomReset),
    ],
  ),
  (
    l.desktopShortcutsApp,
    [
      (keys: ['Ctrl K', 'Ctrl F'], does: l.desktopKeySearch),
      (keys: ['Ctrl V'], does: l.desktopKeyAddLink),
      (keys: ['?'], does: l.desktopKeyShortcuts),
    ],
  ),
];

/// **The shortcuts sheet**, opened with "?".
Future<void> showShortcutsSheet(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialog) {
    final l = dialog.mtl;
    final p = MTThemeX.of(dialog).palette;
    final text = Theme.of(dialog).textTheme;
    return AlertDialog(
      title: Text(l.desktopShortcutsTitle),
      content: SizedBox(
        width: EmberShellSize.formDialog,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (group, lines) in shortcutGroups(l)) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: MTSpace.md,
                    bottom: MTSpace.xs,
                  ),
                  child: Text(
                    group,
                    style: text.labelMedium?.copyWith(color: p.ink3),
                  ),
                ),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: MTSpace.xxs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(line.does, style: text.bodyMedium),
                        ),
                        const SizedBox(width: MTSpace.md),
                        Wrap(
                          spacing: MTSpace.xxs,
                          children: [
                            for (final key in line.keys) KeyCap(label: key),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(l.done),
        ),
      ],
    );
  },
);
