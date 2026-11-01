import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// The transcript beside a full-screen video, with the clip's chapters as
/// a second tab: the one playing lit as playback moves, and a tap plays
/// from there without leaving the picture.
class TranscriptPanelTabs extends StatefulWidget {
  const TranscriptPanelTabs({
    super.key,
    required this.transcript,
    required this.chapters,
    required this.session,
    required this.onClose,
  });

  /// The transcript panel, which carries its own close button.
  final Widget transcript;
  final List<MTChapter> chapters;
  final MTVideoSession session;
  final VoidCallback onClose;

  @override
  State<TranscriptPanelTabs> createState() => _TranscriptPanelTabsState();
}

class _TranscriptPanelTabsState extends State<TranscriptPanelTabs> {
  bool _chapters = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MTSpace.lg,
            MTSpace.md,
            MTSpace.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: MTSpace.xs,
                  runSpacing: MTSpace.xs,
                  children: [
                    MTPanelTab(
                      icon: Icons.subject_rounded,
                      label: l10n.transcript,
                      selected: !_chapters,
                      onTap: () => setState(() => _chapters = false),
                    ),
                    MTPanelTab(
                      icon: Icons.segment_rounded,
                      label: mtMetaLine([
                        l10n.desktopChapters,
                        '${widget.chapters.length}',
                      ]),
                      selected: _chapters,
                      onTap: () => setState(() => _chapters = true),
                    ),
                  ],
                ),
              ),
              // The transcript has a close button of its own.
              if (_chapters)
                IconButton(
                  onPressed: widget.onClose,
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        Expanded(
          child: _chapters
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(MTSpace.lg),
                  child: ListenableBuilder(
                    listenable: widget.session,
                    builder: (context, _) => MTChapterRows(
                      chapters: widget.chapters,
                      current: mtChapterAt(
                        widget.chapters,
                        widget.session.position,
                      ),
                      onSeek: widget.session.seek,
                    ),
                  ),
                )
              : widget.transcript,
        ),
      ],
    );
  }
}
