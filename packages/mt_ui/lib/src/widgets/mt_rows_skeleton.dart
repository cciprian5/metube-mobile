import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_media_row.dart';
import 'mt_skeleton_pulse.dart';

/// The phone library while its first answer is on the way: **flat grey
/// rows the size of the real ones**, so the page has its shape at once and
/// nothing jumps when the clips land. A spinner in the middle of an empty
/// page gave way to a list in one frame. The rows breathe together while
/// they wait ([MTSkeletonPulse]), as the Windows app's own skeleton does;
/// no light sweeps across them.
class MTRowsSkeleton extends StatelessWidget {
  const MTRowsSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final hairline = MTThemeX.of(context).hairline;
    Widget block(double? width, double height, double radius) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return SliverToBoxAdapter(
      child: Semantics(
        label: context.mtl.desktopLibraryLoading,
        child: ExcludeSemantics(
          child: MTSkeletonPulse(
            child: Column(
              children: [
                for (var i = 0; i < count; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: MTSpace.sm,
                      horizontal: MTSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: p.line, width: hairline),
                      ),
                    ),
                    child: Row(
                      children: [
                        block(
                          MTMediaColumns.thumbWidth,
                          MTMediaColumns.thumbHeight,
                          MTRadius.thumb,
                        ),
                        const SizedBox(width: MTSpace.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Rows of different lengths, as titles are.
                              FractionallySizedBox(
                                widthFactor: i.isEven ? 0.85 : 0.65,
                                child: block(null, MTSpace.md, MTRadius.chip),
                              ),
                              const SizedBox(height: MTSpace.sm),
                              FractionallySizedBox(
                                widthFactor: 0.4,
                                child: block(null, MTSpace.sm, MTRadius.chip),
                              ),
                            ],
                          ),
                        ),
                      ],
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
