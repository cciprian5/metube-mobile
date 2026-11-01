import 'package:flutter/material.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The transcript under the audio player** (mobile plan 2026-11-01): the
/// line being said and the next, following playback, on a phone tall
/// enough to hold them. A tap opens the whole text.
class TranscriptPeek extends StatelessWidget {
  const TranscriptPeek({
    super.key,
    required this.segments,
    required this.position,
    required this.onOpen,
  });

  final List<TranscriptSegment> segments;
  final Stream<Duration> position;
  final VoidCallback onOpen;

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
                  Icon(Icons.subject_rounded, size: 16, color: p.ink2),
                  const SizedBox(width: MTSpace.xs),
                  Text(
                    l10n.transcript,
                    style: text.labelLarge!.copyWith(color: p.ink),
                  ),
                  const Spacer(),
                  Text(
                    l10n.transcriptPeekHint,
                    style: text.labelSmall!.copyWith(color: p.ink3),
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
