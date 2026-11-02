import 'package:flutter/material.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'transcript_language.dart';

/// **The transcript under the audio player** (mobile plan 2026-11-01): the
/// line being said and the next, following playback, on a phone tall
/// enough to hold them. A tap opens the whole text; a clip with words in
/// more than one language names the one shown at the top, and a tap on
/// that name moves to the next.
class TranscriptPeek extends StatelessWidget {
  const TranscriptPeek({
    super.key,
    required this.segments,
    required this.position,
    required this.onOpen,
    required this.language,
    this.onSwitch,
  });

  final List<TranscriptSegment> segments;
  final Stream<Duration> position;
  final VoidCallback onOpen;

  /// The code of the language shown.
  final String language;

  /// Moves to the next language; null when the clip has only this one.
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l10n = context.mtl;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTRadius.card),
        side: BorderSide(color: p.line, width: MTThemeX.of(context).hairline),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(MTRadius.card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MTSpace.md,
            MTSpace.sm,
            MTSpace.md,
            MTSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  MTIcon(MTIcons.transcript, size: 16, color: p.ink2),
                  const SizedBox(width: MTSpace.xs),
                  // The title and the note share the line and give way to
                  // each other on a small phone or a large font.
                  Expanded(
                    child: Text(
                      l10n.transcript,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge!.copyWith(color: p.ink),
                    ),
                  ),
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: switch (onSwitch) {
                        final onSwitch? => Tooltip(
                          message: l10n.transcriptSwitchLanguage,
                          child: TextButton.icon(
                            onPressed: onSwitch,
                            style: TextButton.styleFrom(
                              foregroundColor: p.ink2,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const MTIcon(MTIcons.swap, size: 16),
                            label: Text(
                              mtLanguageName(language),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall!.copyWith(color: p.ink2),
                            ),
                          ),
                        ),
                        null => Text(
                          l10n.transcriptPeekHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall!.copyWith(color: p.ink3),
                        ),
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MTSpace.xs),
              StreamBuilder<Duration>(
                stream: position,
                builder: (context, snapshot) {
                  final at = segmentAt(
                    segments,
                    snapshot.data ?? Duration.zero,
                  );
                  final now = at ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final i in [now, now + 1])
                        if (i < segments.length)
                          Text(
                            segments[i].text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall!.copyWith(
                              color: i == at ? p.ink : p.ink3,
                              fontWeight: i == at ? FontWeight.w500 : null,
                            ),
                          ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The peek for the clip playing, in the language picked last (shared with
/// the video's subtitles), else the app's own; the name at its top moves
/// to the next language and every player follows. It once showed whichever
/// transcript was kept first, Arabic whatever the app's language
/// (field report 2026-11-01).
class PlayingTranscriptPeek extends StatelessWidget {
  const PlayingTranscriptPeek({
    super.key,
    required this.transcripts,
    required this.chosen,
    required this.position,
    required this.onOpen,
  });

  /// At least one of them has words.
  final List<Transcript> transcripts;
  final ValueNotifier<String?> chosen;
  final Stream<Duration> position;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final interface = Localizations.localeOf(context).languageCode;
    final spoken = transcripts.where((t) => !t.isEmpty).length;
    return ValueListenableBuilder(
      valueListenable: chosen,
      builder: (context, code, _) {
        final shown = preferredTranscript(
          transcripts,
          chosen: code,
          interface: interface,
        )!;
        return TranscriptPeek(
          segments: shown.segments,
          position: position,
          onOpen: onOpen,
          language: shown.language,
          onSwitch: spoken < 2
              ? null
              : () => chosen.value = nextLanguage(transcripts, shown.language),
        );
      },
    );
  }
}
