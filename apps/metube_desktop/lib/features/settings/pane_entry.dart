import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../router.dart';
import 'pane_values.dart';
import 'settings_place.dart';

/// One section in the list beside the settings: its icon, its name, and
/// the setting as it stands, so a look down the list answers most questions
/// without opening anything.
MTIconData _paneIcon(EmberSettingsPane pane) => switch (pane) {
  EmberSettingsPane.server => MTIcons.server,
  EmberSettingsPane.network => MTIcons.globe,
  EmberSettingsPane.subscriptions => MTIcons.subscriptions,
  EmberSettingsPane.cookies => MTIcons.cookie,
  EmberSettingsPane.downloads => MTIcons.download,
  EmberSettingsPane.folders => MTIcons.folder,
  EmberSettingsPane.appearance => MTIcons.appearance,
  EmberSettingsPane.desktop => MTIcons.monitor,
  EmberSettingsPane.transcripts => MTIcons.transcript,
  EmberSettingsPane.backup => MTIcons.backup,
  EmberSettingsPane.sync => MTIcons.swap,
  EmberSettingsPane.updates => MTIcons.saveTo,
  EmberSettingsPane.logs => MTIcons.list,
  EmberSettingsPane.about => MTIcons.info,
};

class PaneEntry extends ConsumerWidget {
  const PaneEntry({
    super.key,
    required this.pane,
    required this.selected,
    required this.onTap,
  });

  final EmberSettingsPane pane;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final ink = selected ? p.ink : p.ink2;
    final label = paneTitle(context.mtl, pane);
    final value = paneValue(context, ref, pane);
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.xxs),
      child: AnimatedContainer(
        // The fill eases from one choice to the next, as the border does.
        duration: mtMotionDuration(context, MTMotion.fast),
        decoration: ShapeDecoration(
          color: selected ? mtSelectedFill(p) : p.ink.withValues(alpha: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MTCorners.desktop.field),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(MTCorners.desktop.field),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MTCorners.desktop.field),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MTSpace.sm,
                vertical: MTSpace.xs,
              ),
              child: Row(
                children: [
                  MTIcon(
                    _paneIcon(pane),
                    size: MTDensity.desktop.icon,
                    color: ink,
                  ),
                  const SizedBox(width: MTSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: p.ink,
                            fontWeight: selected ? FontWeight.w700 : null,
                          ),
                        ),
                        // The setting as it stands, so a look down the list
                        // answers most questions without opening anything.
                        if (value != null)
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(color: p.ink3),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
