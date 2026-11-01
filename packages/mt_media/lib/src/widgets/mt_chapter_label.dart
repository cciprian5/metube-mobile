import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'mt_chapters.dart';

/// The chapter playing, beside the time over the video: its number and
/// opening words, which open the list. Nothing before the first chapter.
class MTChapterLabel extends StatelessWidget {
  const MTChapterLabel({
    super.key,
    required this.chapters,
    required this.position,
    required this.onTap,
  });

  final List<MTChapter> chapters;
  final Duration position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = mtChapterAt(chapters, position);
    if (at == null) return const SizedBox.shrink();
    final ink = MTPalette.serverCardInk.withValues(alpha: 0.85);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MTRadius.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MTSpace.xs,
          vertical: MTSpace.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                mtMetaLine([
                  context.mtl.chapterNumber(at + 1),
                  chapters[at].opening,
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: ink),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: ink),
          ],
        ),
      ),
    );
  }
}
