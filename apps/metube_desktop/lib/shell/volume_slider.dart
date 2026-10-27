import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../data/volume.dart';

/// The player bar's volume: the speaker and a short slider. ↑ and ↓ move
/// the same level, so either way it is kept between runs.
class EmberVolumeSlider extends ConsumerWidget {
  const EmberVolumeSlider({super.key});

  static const double width = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final level = ref.watch(volumeProvider);
    return MTShortcutTooltip(
      message: l.desktopVolume,
      shortcut: '↑ ↓',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MTIcon(
            MTIcons.volume,
            size: MTSpace.lg,
            color: level == 0 ? p.ink3 : p.ink2,
          ),
          // Low to high from left to right, as the seek bar runs, in
          // either language.
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: width,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: MTSpace.xxs / 2,
                  activeTrackColor: p.accent,
                  inactiveTrackColor: p.line2,
                  thumbColor: p.accent,
                  overlayColor: p.accentSoft,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: MTSpace.xs,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: MTSpace.md,
                  ),
                ),
                child: Slider(
                  label: l.desktopVolume,
                  semanticFormatterCallback: (v) =>
                      l.desktopVolumeLevel(v.round()),
                  value: level,
                  max: 100,
                  onChanged: (v) =>
                      unawaited(ref.read(volumeProvider.notifier).set(v)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
