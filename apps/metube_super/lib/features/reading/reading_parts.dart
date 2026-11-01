import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_ui/mt_ui.dart';

import 'reading_export.dart';

/// Where the clip being read is playing, when it is: its time, a way to
/// move it, and to pause it. The page follows it only while [stillPlaying]
/// holds, so another clip's time never lights this one's words.
class ReadingPlayback {
  const ReadingPlayback({
    required this.positions,
    required this.seek,
    required this.stillPlaying,
    this.playing,
    this.playPause,
  });

  /// A new stream of the time for each listener: a video's is sampled,
  /// and a sampled stream takes one listener only.
  final Stream<Duration> Function() positions;
  final Future<void> Function(Duration at) seek;
  final bool Function() stillPlaying;
  final Stream<bool>? playing;
  final VoidCallback? playPause;
}

/// The search over the text: the words, which match of how many, and the
/// way between them.
class ReadingFindBar extends StatelessWidget {
  const ReadingFindBar({
    super.key,
    required this.field,
    required this.at,
    required this.count,
    required this.onChanged,
    required this.onStep,
    required this.onClose,
  });

  final TextEditingController field;

  /// The match shown, counted from zero; null with none.
  final int? at;
  final int count;
  final VoidCallback onChanged;
  final ValueChanged<int> onStep;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.pagePad,
        0,
        MTSpace.xs,
        MTSpace.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: field,
              autofocus: true,
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                isDense: true,
                hintText: l.desktopReadingFind,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: MTSpace.xs),
            Text(
              mtLtrRun(l.desktopReadingFound((at ?? 0) + 1, count)),
              style: Theme.of(context).textTheme.labelSmall!
                  .copyWith(color: p.ink3),
            ),
          ],
          IconButton(
            onPressed: count == 0 ? null : () => onStep(-1),
            tooltip: l.desktopReadingPreviousMatch,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            onPressed: count == 0 ? null : () => onStep(1),
            tooltip: l.desktopReadingNextMatch,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: l.desktopReadingCloseFind,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

/// The four forms the text is shared in, each saying what it is for.
Future<ReadingExport?> pickReadingExport(BuildContext context) {
  final l = context.mtl;
  return showMTSheet<ReadingExport>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(
        MTSpace.pagePad,
        MTSpace.lg,
        MTSpace.pagePad,
        mtSheetBottomPad(sheet),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MTSectionHeader(title: l.readingShare),
          for (final (form, title, hint) in [
            (ReadingExport.text, l.readingAsText, l.readingAsTextHint),
            (
              ReadingExport.markdown,
              l.desktopExportMarkdown,
              l.readingAsMarkdownHint,
            ),
            (ReadingExport.srt, l.desktopExportSrt, l.readingAsSrtHint),
            (ReadingExport.pdf, l.desktopExportPdf, l.readingAsPdfHint),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: Text(hint),
              onTap: () => Navigator.of(sheet).pop(form),
            ),
        ],
      ),
    ),
  );
}

/// The clip playing, under the page, as the mini player is under the
/// library: its name and time, and its play button.
class ReadingPlaybackBar extends StatefulWidget {
  const ReadingPlaybackBar({
    super.key,
    required this.title,
    required this.playback,
  });

  final String title;
  final ReadingPlayback playback;

  @override
  State<ReadingPlaybackBar> createState() => _ReadingPlaybackBarState();
}

class _ReadingPlaybackBarState extends State<ReadingPlaybackBar> {
  late final _position = widget.playback.positions();

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    final title = widget.title;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Material(
      color: p.miniBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MTSpace.pagePad,
            MTSpace.xs,
            MTSpace.xs,
            MTSpace.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: MTForeignText(
                  title,
                  maxLines: 1,
                  style: text.labelLarge!.copyWith(color: p.miniInk),
                ),
              ),
              StreamBuilder<Duration>(
                stream: _position,
                builder: (context, at) => Text(
                  mtLtrRun(mtFormatDuration(at.data ?? Duration.zero)),
                  style: text.labelSmall!
                      .copyWith(color: p.miniInkMuted)
                      .tabular,
                ),
              ),
              if (playback.playPause case final playPause?)
                StreamBuilder<bool>(
                  stream: playback.playing,
                  builder: (context, playing) => IconButton(
                    onPressed: playPause,
                    color: p.miniInk,
                    tooltip: (playing.data ?? false)
                        ? context.mtl.pause
                        : context.mtl.play,
                    icon: MTIconSwap(
                      icon: (playing.data ?? false)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: p.miniInk,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
