import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The library while its first answer is on the way: **flat grey cards at
/// the size the real ones will have**, so the page has its shape at once
/// and nothing jumps when the clips land. No shimmer sweeps across them; a
/// moving light on a placeholder is one of the marks of a generated screen,
/// and the wait is short.
class LibrarySkeleton extends StatelessWidget {
  const LibrarySkeleton({super.key, this.count = 8});

  final int count;

  /// About the width of a grid card at the usual window size.
  static const double _card = 220;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(MTCorners.desktop.box),
      ),
    );
    return Semantics(
      label: context.mtl.desktopLibraryLoading,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: MTSpace.lg,
          runSpacing: MTSpace.xl,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                width: _card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: _card * 9 / 16,
                      decoration: BoxDecoration(
                        color: p.cardAlt,
                        borderRadius: BorderRadius.circular(
                          MTCorners.desktop.thumb,
                        ),
                      ),
                    ),
                    const SizedBox(height: MTSpace.sm),
                    bar(_card * 0.85, MTSpace.sm),
                    const SizedBox(height: MTSpace.xs),
                    bar(_card * 0.5, MTSpace.xs),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
