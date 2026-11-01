import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'media_time.dart';

/// One chapter of a clip: where it begins, and its opening words. The app
/// works them out (from a transcript, which this package does not know);
/// the record has the same shape as the transcripts package's, so its
/// chapters pass straight in.
typedef MTChapter = ({Duration start, String opening});

/// The chapter playing at [position]: the last to have begun. Null before
/// the first, or for a clip without chapters.
int? mtChapterAt(List<MTChapter> chapters, Duration position) {
  int? at;
  for (final (i, chapter) in chapters.indexed) {
    if (chapter.start > position) break;
    at = i;
  }
  return at;
}

/// Chapters as rows: the time each begins and its opening words, the one
/// playing lit. A tap plays from there.
class MTChapterRows extends StatelessWidget {
  const MTChapterRows({
    super.key,
    required this.chapters,
    required this.current,
    required this.onSeek,
    this.from = 0,
    this.count,
  });

  final List<MTChapter> chapters;
  final int? current;
  final ValueChanged<Duration> onSeek;

  /// The first row shown, and how many; all of them by default.
  final int from;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final to = count == null
        ? chapters.length
        : (from + count!).clamp(0, chapters.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = from; i < to; i++)
          Semantics(
            button: true,
            selected: i == current,
            child: Material(
              color: i == current ? mtSelectedFill(p) : Colors.transparent,
              borderRadius: BorderRadius.circular(MTRadius.field),
              child: InkWell(
                key: ValueKey('chapter-$i'),
                borderRadius: BorderRadius.circular(MTRadius.field),
                onTap: () => onSeek(chapters[i].start),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MTSpace.sm,
                    vertical: MTSpace.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mtLtrRun(mtFormatDuration(chapters[i].start)),
                        style: text.labelMedium!
                            .copyWith(
                              color: i == current ? p.accentInk : p.ink3,
                            )
                            .tabular,
                      ),
                      const SizedBox(width: MTSpace.md),
                      Expanded(
                        child: MTForeignText(
                          chapters[i].opening,
                          maxLines: 2,
                          style: text.bodySmall!.copyWith(
                            color: i == current ? p.ink : p.ink2,
                            fontWeight: i == current ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// **The chapters under the player's buttons**: a few around the one
/// playing, and the way to all of them. An arrow in the heading folds
/// them away and back; [folded] keeps that choice where the app wants it
/// kept, and without one it lasts as long as the section.
class MTChapterSection extends StatefulWidget {
  const MTChapterSection({
    super.key,
    required this.chapters,
    required this.current,
    required this.onSeek,
    required this.onShowAll,
    this.folded,
  });

  /// How many rows the section shows before "View all".
  static const shown = 4;

  final List<MTChapter> chapters;
  final int? current;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onShowAll;
  final ValueNotifier<bool>? folded;

  @override
  State<MTChapterSection> createState() => _MTChapterSectionState();
}

class _MTChapterSectionState extends State<MTChapterSection> {
  final _own = ValueNotifier(false);

  ValueNotifier<bool> get _folded => widget.folded ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final chapters = widget.chapters;
    final last = chapters.length - MTChapterSection.shown;
    // The one playing second from the top, so what comes next shows.
    final from = ((widget.current ?? 0) - 1).clamp(0, last < 0 ? 0 : last);
    final still = MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder(
      valueListenable: _folded,
      builder: (context, folded, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MTSectionHeader(
            title: l10n.desktopChapters,
            trailing: l10n.chaptersFromTranscript(chapters.length),
            action: IconButton(
              key: const ValueKey('chapters-fold'),
              onPressed: () => _folded.value = !folded,
              tooltip: folded ? l10n.chaptersUnfold : l10n.chaptersFold,
              visualDensity: VisualDensity.compact,
              icon: AnimatedRotation(
                turns: folded ? 0.5 : 0,
                duration: still ? Duration.zero : MTMotion.fast,
                child: Icon(Icons.expand_less_rounded, color: p.ink2),
              ),
            ),
          ),
          AnimatedSize(
            duration: still ? Duration.zero : MTMotion.medium,
            curve: MTMotion.ease,
            alignment: AlignmentDirectional.topCenter,
            child: folded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: MTSpace.xs),
                      MTChapterRows(
                        chapters: chapters,
                        current: widget.current,
                        onSeek: widget.onSeek,
                        from: from,
                        count: MTChapterSection.shown,
                      ),
                      if (chapters.length > MTChapterSection.shown)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: widget.onShowAll,
                            child: Text(l10n.chaptersShowAll),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Every chapter in a sheet, the one playing lit as playback moves; a tap
/// closes the sheet and plays from there.
Future<void> showMTChapterSheet(
  BuildContext context, {
  required List<MTChapter> chapters,
  required Listenable ticks,
  required Duration Function() position,
  required ValueChanged<Duration> onSeek,
}) => showMTSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheet) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(sheet).height * 0.75,
    ),
    child: Padding(
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
          MTSectionHeader(
            title: sheet.mtl.desktopChapters,
            trailing: sheet.mtl.chaptersFromTranscript(chapters.length),
          ),
          const SizedBox(height: MTSpace.xs),
          Flexible(
            child: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: ticks,
                builder: (context, _) => MTChapterRows(
                  chapters: chapters,
                  current: mtChapterAt(chapters, position()),
                  onSeek: (start) {
                    Navigator.of(sheet).pop();
                    onSeek(start);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
