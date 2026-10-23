import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'pill.dart';
import 'shell_metrics.dart';

/// The panel's three faces.
enum PanelTab { transcript, upNext, details }

/// The side panel: the transcript following playback, what comes next,
/// and the clip's details. The faces themselves are filled by the steps
/// that build them; the shell gives them their place and their tabs.
class EmberRightPanel extends StatelessWidget {
  const EmberRightPanel({
    super.key,
    required this.tab,
    required this.onTab,
    required this.state,
  });

  final PanelTab tab;
  final ValueChanged<PanelTab> onTab;
  final MTPlayerState state;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final current = state.current;
    return Container(
      width: EmberShellSize.panel,
      decoration: BoxDecoration(
        color: p.bg,
        border: BorderDirectional(start: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.all(MTSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: MTSpace.xs,
            runSpacing: MTSpace.xs,
            children: [
              for (final (face, label) in [
                (PanelTab.transcript, l.transcript),
                (PanelTab.upNext, l.upNext),
                (PanelTab.details, l.details),
              ])
                EmberPill(
                  label: label,
                  selected: tab == face,
                  onTap: () => onTab(face),
                ),
            ],
          ),
          const SizedBox(height: MTSpace.lg),
          if (current == null)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: MTEmptyFrame(
                    title: l.desktopNothingPlaying,
                    message: l.desktopNothingPlayingHint,
                  ),
                ),
              ),
            )
          else
            Text(
              current.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: mtTextDirectionOf(
                current.title,
                Directionality.of(context),
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
        ],
      ),
    );
  }
}
