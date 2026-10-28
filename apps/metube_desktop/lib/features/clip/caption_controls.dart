import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/subtitles_data.dart';
import '../../shell/context_menu.dart';
import '../../shell/pill.dart';
import '../../shell/player_controls.dart';
import '../settings/appearance_pane.dart';

/// The subtitles [item] has, as the player draws them: every language it
/// comes in (the switch walks them), at the size and over the background
/// chosen. Null for a clip with no transcript.
MTCaptions? emberCaptionsFor(WidgetRef ref, PlaylistItem item) {
  final tracks = ref.watch(
    captionTracksProvider((
      canonicalUrl: item.canonicalUrl,
      serverFilename: item.serverFilename,
    )),
  );
  if (tracks == null) return null;
  final subtitles = ref.watch(emberSubtitlesProvider);
  return MTCaptions(
    lines: tracks.values.first,
    tracks: tracks,
    language: subtitles.language,
    shown: subtitles.shown,
    scale: subtitles.scale,
    background: subtitles.backdrop,
  );
}

/// The subtitles' buttons on the picture, as on the phone: the language
/// on screen ("AR", "EN"; a click moves to the next) while they show and
/// the clip has more than one, CC, and a menu of the size, the background
/// and the language.
class EmberCaptionButtons extends ConsumerWidget {
  const EmberCaptionButtons({super.key, required this.item});

  final PlaylistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitles = ref.watch(emberSubtitlesProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([
        subtitles.shown,
        subtitles.language,
        subtitles.size,
        subtitles.background,
      ]),
      builder: (context, _) {
        final captions = emberCaptionsFor(ref, item);
        if (captions == null) return const SizedBox.shrink();
        final l = context.mtl;
        final accent = MTThemeX.of(context).palette.accent;
        final on = subtitles.shown.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (on && captions.switchable)
              MTShortcutTooltip(
                message: l.subtitlesLanguage,
                child: TextButton(
                  onPressed: captions.nextLanguage,
                  child: Text(
                    _code(captions.current),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            EmberPlayerControl(
              icon: MTIcons.captions,
              label: on ? l.subtitlesHide : l.subtitlesShow,
              shortcut: 'C',
              selected: on,
              ink: Colors.white,
              color: accent,
              onTap: subtitles.toggle,
            ),
            Builder(
              builder: (button) => EmberPlayerControl(
                icon: MTIcons.chevronDown,
                label: l.desktopSubtitleOptions,
                ink: Colors.white,
                onTap: () => unawaited(_menu(button, captions, subtitles)),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _code(String? language) =>
      (language ?? '').split('-').first.toUpperCase();

  /// The size, the background and the language, the chosen ones ticked,
  /// opened under the button.
  static Future<void> _menu(
    BuildContext button,
    MTCaptions captions,
    EmberSubtitles subtitles,
  ) async {
    final l = button.mtl;
    final box = button.findRenderObject()! as RenderBox;
    final at = box.localToGlobal(box.size.bottomCenter(Offset.zero));
    MTIconData? tick(bool chosen) => chosen ? MTIcons.check : null;
    final choice = await showEmberMenu<String>(button, at, [
      for (final (i, size) in _sizes(l).indexed)
        EmberMenuEntry(
          's$i',
          tick(subtitles.size.value == i),
          '${l.subtitlesSize} · $size',
        ),
      const EmberMenuEntry.divider(),
      for (final (i, kind) in _backgrounds(l).indexed)
        EmberMenuEntry(
          'b$i',
          tick(subtitles.background.value == i),
          '${l.subtitlesBackground} · $kind',
        ),
      if (captions.tracks.length > 1) ...[
        const EmberMenuEntry.divider(),
        for (final code in captions.tracks.keys)
          EmberMenuEntry(
            'l$code',
            tick(captions.current == code),
            '${l.subtitlesLanguage} · ${_code(code)}',
          ),
      ],
    ]);
    if (choice == null) return;
    final rest = choice.substring(1);
    switch (choice[0]) {
      case 's':
        subtitles.size.value = int.parse(rest);
      case 'b':
        subtitles.background.value = int.parse(rest);
      case 'l':
        subtitles.language.value = rest;
    }
  }
}

List<String> _sizes(MTLocalizations l) => [
  l.subtitlesSizeSmall,
  l.subtitlesSizeMedium,
  l.subtitlesSizeLarge,
];

List<String> _backgrounds(MTLocalizations l) => [
  l.subtitlesBackgroundSolid,
  l.subtitlesBackgroundFaint,
  l.subtitlesBackgroundNone,
];

/// The subtitles' size and background in Settings, the phone's choices.
class CaptionStyleChoices extends ConsumerWidget {
  const CaptionStyleChoices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final subtitles = ref.watch(emberSubtitlesProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([subtitles.size, subtitles.background]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoiceGroup(
            title: l.subtitlesSize,
            children: [
              for (final (i, label) in _sizes(l).indexed)
                EmberPill(
                  label: label,
                  selected: subtitles.size.value == i,
                  onTap: () => subtitles.size.value = i,
                ),
            ],
          ),
          ChoiceGroup(
            title: l.subtitlesBackground,
            hint: l.subtitlesBackgroundHelp,
            children: [
              for (final (i, label) in _backgrounds(l).indexed)
                EmberPill(
                  label: label,
                  selected: subtitles.background.value == i,
                  onTap: () => subtitles.background.value = i,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
