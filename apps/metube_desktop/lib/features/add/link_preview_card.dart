import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library/artwork.dart';
import 'link_preview.dart';

/// The clip about to be added, as its site names it: picture, title and
/// channel. Nothing at all for a site that offers no preview, rather than
/// an empty frame.
class LinkPreviewCard extends ConsumerWidget {
  const LinkPreviewCard({super.key, required this.url});

  final String url;

  static const double _thumbWidth = 160;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final asked = ref.watch(linkPreviewProvider(url));
    if (asked.isLoading) return const MTFilmStrip();
    final preview = asked.valueOrNull;
    if (preview == null) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MTMediaThumb(
          width: _thumbWidth,
          height: _thumbWidth * 9 / 16,
          child: artworkFor(
            ref,
            context,
            preview.thumbnail,
            width: _thumbWidth,
          ),
        ),
        const SizedBox(width: MTSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textDirection: mtTextDirectionOf(
                  preview.title,
                  Directionality.of(context),
                ),
                style: text.titleSmall?.copyWith(color: p.ink),
              ),
              if (preview.author case final who?)
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: p.ink3),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
