import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import '../../data/folders_data.dart';
import '../../shell/pill.dart';
import '../folders/folder_picker.dart';

/// What an add sends with every link: video or sound, the quality, and
/// the server folder. **The folder is never remembered**, as on the phone:
/// a folder chosen once and silently kept files the next clip where the
/// user did not look.
class AddChoice {
  const AddChoice({
    this.audio = false,
    this.quality = Quality.best,
    this.folder = FolderChoice.top,
    this.pullAfter = false,
    this.pullInto,
  });

  /// An add as Downloads' default quality starts it: on sound when that is
  /// audio.
  factory AddChoice.startingWith(Quality quality) => quality == Quality.audio
      ? const AddChoice(audio: true)
      : AddChoice(quality: quality);

  final bool audio;

  /// The video quality; numbers are YouTube's alone.
  final Quality quality;
  final FolderChoice folder;

  /// Once the server has it, a copy comes to this computer too (the Lite
  /// habit, without its delete).
  final bool pullAfter;

  /// Where that copy goes, chosen for this add alone; null is the
  /// download folder.
  final String? pullInto;

  /// What is sent for [url]: sound, or the video quality after the rule
  /// that numbers are for YouTube alone.
  Quality qualityFor(String url) =>
      audio ? Quality.audio : quality.applyRule(url);

  String? get folderPath => folder.isTop ? null : folder.path;

  AddChoice copyWith({
    bool? audio,
    Quality? quality,
    FolderChoice? folder,
    bool? pullAfter,
    String? pullInto,
  }) => AddChoice(
    audio: audio ?? this.audio,
    quality: quality ?? this.quality,
    folder: folder ?? this.folder,
    pullAfter: pullAfter ?? this.pullAfter,
    pullInto: pullInto ?? this.pullInto,
  );
}

/// The choices under the link(s): video or audio, the video's quality
/// (the numbers for YouTube only), the folder, for one YouTube clip "fetch
/// its transcript first", and "then download it to this computer".
class AddOptions extends ConsumerWidget {
  const AddOptions({
    super.key,
    required this.choice,
    required this.onChanged,
    required this.youtube,
    this.offerTranscript = false,
    this.audioOnly = false,
  });

  final AddChoice choice;
  final ValueChanged<AddChoice> onChanged;

  /// Whether the numbered qualities apply (every link is YouTube).
  final bool youtube;
  final bool offerTranscript;

  /// A SoundCloud set: sound is the only choice.
  final bool audioOnly;

  Future<void> _pickPullFolder(WidgetRef ref, AddChoice choice) async {
    final picked = await ref
        .read(desktopFoldersProvider)
        .pick(
          initial:
              choice.pullInto ?? ref.read(downloadFolderProvider).valueOrNull,
        );
    if (picked != null) onChanged(choice.copyWith(pullInto: picked));
  }

  Future<void> _pickFolder(BuildContext context) async {
    final picked = await showFolderPicker(
      context,
      audio: choice.audio || audioOnly,
      current: choice.folder,
    );
    if (picked != null) onChanged(choice.copyWith(folder: picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final audio = choice.audio || audioOnly;
    final qualities = [
      (Quality.best, l.qualityBest),
      if (youtube) ...[
        (Quality.q1080, l.quality1080),
        (Quality.q720, l.quality720),
        (Quality.q480, l.quality480),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: MTSpace.xs,
          runSpacing: MTSpace.xs,
          children: [
            if (!audioOnly)
              EmberPill(
                label: l.filterVideo,
                icon: MTIcons.library,
                selected: !audio,
                onTap: () => onChanged(choice.copyWith(audio: false)),
              ),
            EmberPill(
              label: l.filterAudio,
              icon: MTIcons.headphones,
              selected: audio,
              onTap: () => onChanged(choice.copyWith(audio: true)),
            ),
          ],
        ),
        if (!audio) ...[
          const SizedBox(height: MTSpace.sm),
          Wrap(
            spacing: MTSpace.xs,
            runSpacing: MTSpace.xs,
            children: [
              for (final (quality, label) in qualities)
                EmberPill(
                  label: label,
                  selected:
                      choice.quality == quality ||
                      (!youtube && quality == Quality.best),
                  onTap: () => onChanged(choice.copyWith(quality: quality)),
                ),
            ],
          ),
        ],
        const SizedBox(height: MTSpace.md),
        FolderLine(
          value: folderLabel(l, choice.folder),
          onPick: () => unawaited(_pickFolder(context)),
        ),
        if (offerTranscript)
          Padding(
            padding: const EdgeInsets.only(top: MTSpace.xs),
            child: CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: ref.watch(transcriptsFirstProvider),
              onChanged: (on) => unawaited(
                ref.read(transcriptsFirstProvider.notifier).set(on ?? false),
              ),
              title: Text(
                l.desktopTranscriptFirst,
                style: text.bodySmall?.copyWith(color: p.ink),
              ),
              subtitle: Text(
                l.transcriptsSearchHelp,
                style: text.labelSmall?.copyWith(color: p.ink3),
              ),
            ),
          ),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: choice.pullAfter,
          onChanged: (on) => onChanged(choice.copyWith(pullAfter: on ?? false)),
          title: Text(
            l.desktopPullAfter,
            style: text.bodySmall?.copyWith(color: p.ink),
          ),
        ),
        // Where it will land, said before it is sent; asked later instead
        // when the user wants to be asked each time.
        if (choice.pullAfter && !ref.watch(folderSettingsProvider).askEachTime)
          FolderLine(
            label: l.desktopDownloadFolder,
            value:
                choice.pullInto ??
                ref.watch(downloadFolderProvider).valueOrNull ??
                l.desktopFolderUnavailable,
            onPick: () => unawaited(_pickPullFolder(ref, choice)),
          ),
      ],
    );
  }
}
