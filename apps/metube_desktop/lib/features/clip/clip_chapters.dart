import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/transcripts_data.dart';
import '../../di.dart';
import '../../shell/section_header.dart';
import 'chapters.dart';
import 'clip_state.dart';

/// The clip's chapters under its title, from its transcript: each one's
/// time and opening words, the one playing lit. A click plays from there.
/// Nothing at all when the transcript gives none.
class ClipChapters extends ConsumerStatefulWidget {
  const ClipChapters({super.key, required this.item, required this.isCurrent});

  final PlaylistItem item;
  final bool isCurrent;

  @override
  ConsumerState<ClipChapters> createState() => _ClipChaptersState();
}

class _ClipChaptersState extends ConsumerState<ClipChapters> {
  late final MTPlayer _player = ref.read(playerProvider);
  StreamSubscription<Duration>? _positions;

  /// The chapters of the transcript last drawn, worked out once for it.
  Transcript? _from;
  List<Chapter> _chapters = const [];
  int? _now;

  @override
  void initState() {
    super.initState();
    _positions = _player.positionStream.listen(_follow);
  }

  @override
  void didUpdateWidget(ClipChapters old) {
    super.didUpdateWidget(old);
    if (old.isCurrent != widget.isCurrent) _follow(_player.position);
  }

  @override
  void dispose() {
    unawaited(_positions?.cancel());
    super.dispose();
  }

  int? _chapterAt(Duration position) {
    if (!widget.isCurrent) return null;
    final at = _chapters.lastIndexWhere((c) => c.start <= position);
    return at < 0 ? null : at;
  }

  void _follow(Duration position) {
    final now = _chapterAt(position);
    if (now != _now && mounted) setState(() => _now = now);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final transcript = ref
        .watch(
          transcriptForProvider((
            canonicalUrl: item.canonicalUrl,
            serverFilename: item.serverFilename,
          )),
        )
        .valueOrNull;
    if (transcript != _from) {
      _from = transcript;
      _chapters = transcript == null
          ? const []
          : chaptersOf(transcript.segments);
      _now = _chapterAt(_player.position);
    }
    if (_chapters.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: MTSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmberSectionHeader(title: context.mtl.desktopChapters),
          const SizedBox(height: MTSpace.xs),
          for (final (i, chapter) in _chapters.indexed)
            _ChapterRow(
              chapter: chapter,
              current: i == _now,
              onTap: () => unawaited(
                playFrom(
                  _player,
                  item,
                  isCurrent: widget.isCurrent,
                  at: chapter.start,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.chapter,
    required this.current,
    required this.onTap,
  });

  final Chapter chapter;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final corner = BorderRadius.circular(MTCorners.desktop.thumb);
    return Semantics(
      button: true,
      selected: current,
      child: Material(
        color: current ? p.accentSoft : Colors.transparent,
        borderRadius: corner,
        child: InkWell(
          onTap: onTap,
          borderRadius: corner,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.sm,
              vertical: MTSpace.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mtLtrRun(mtFormatDuration(chapter.start)),
                  style: text.labelLarge?.tabular.copyWith(
                    color: current ? p.accentInk : p.ink3,
                  ),
                ),
                const SizedBox(width: MTSpace.md),
                Expanded(
                  child: Text(
                    chapter.opening,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: mtTextDirectionOf(
                      chapter.opening,
                      Directionality.of(context),
                    ),
                    style: text.bodyMedium?.copyWith(
                      color: current ? p.ink : p.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
