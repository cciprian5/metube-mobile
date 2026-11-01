import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_done_motion.dart';
import 'mt_polish.dart';

/// A live Wahaj download card: a soft accent ground, a progress bar and a
/// cancel. The status text, whether a phase or an error, arrives already
/// translated from the app.
class MTDownloadProgressCard extends StatelessWidget {
  const MTDownloadProgressCard({
    super.key,
    required this.title,
    required this.statusText,
    this.progress,
    this.isError = false,
    this.onCancel,
    this.thumbnail,
    this.detail,
    this.waiting = false,
    this.done = false,
  });

  final String title;
  final String statusText;

  /// 0 to 1, or null while indeterminate during the add and wait phases.
  final double? progress;
  final bool isError;
  final VoidCallback? onCancel;
  final Widget? thumbnail;

  /// A figure beside the percentage, such as the download speed.
  final String? detail;

  /// Waiting its turn: a still, dashed line rather than a moving bar, which
  /// would claim work is being done.
  final bool waiting;

  /// Just finished: the bar full and a check drawn where the cancel was.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    // **Colour for the data alone** (log §4, 2026-10-31): the bar and its
    // figure in the accent, a failure's sentence in the error colour. The
    // card itself stays neutral; tinted and framed in the accent, every
    // download looked like an alert, and a failure wore three marks.
    final tint = isError ? p.err : p.accent;
    final softInk = isError ? p.err : p.ink3;
    final hairline = MTThemeX.of(context).hairline;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.md + 1,
        vertical: MTSpace.md,
      ),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(MTRadius.card),
        border: Border.all(color: p.line, width: hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.cardAlt,
              borderRadius: BorderRadius.circular(MTRadius.thumb),
            ),
            child:
                thumbnail ??
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.download_rounded,
                  size: 22,
                  color: p.ink3,
                ),
          ),
          const SizedBox(width: MTSpace.md - 1),
          Expanded(
            // **The bar and the number glide to each new reading** (field
            // report 2026-10-15) instead of jumping to it, so a figure
            // that arrives in steps still reads as a count.
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                end: done ? 1 : progress?.clamp(0, 1).toDouble() ?? 0,
              ),
              duration: mtMotionDuration(
                context,
                const Duration(milliseconds: 450),
              ),
              curve: Curves.easeOut,
              builder: (context, shown, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(color: softInk),
                        ),
                      ),
                      // **The percentage follows every phase that knows its
                      // progress** (field report 2026-09-03: the counter did
                      // not appear while pulling to the device). The number
                      // used to be buried inside the "on server %" string
                      // alone, so the pull phase, the longest one in Lite,
                      // showed a moving bar with no number. It is an
                      // independent element now, so it appears during both
                      // the pull and the poll without a separate string per
                      // phase.
                      if (!isError && detail != null) ...[
                        const SizedBox(width: MTSpace.sm),
                        Text(
                          detail!,
                          style: text.bodySmall!.copyWith(color: p.ink3),
                        ),
                      ],
                      if (!isError && progress != null) ...[
                        const SizedBox(width: MTSpace.sm),
                        Text(
                          '${(shown * 100).round()}%',
                          style: text.bodySmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tint,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isError && waiting) ...[
                    const SizedBox(height: MTSpace.xs + 1),
                    _DashedLine(color: p.line2),
                  ] else if (!isError) ...[
                    const SizedBox(height: MTSpace.xs + 1),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress == null ? null : shown,
                        minHeight: 5,
                        backgroundColor: p.line,
                        valueColor: AlwaysStoppedAnimation(tint),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (done) ...[
            const SizedBox(width: MTSpace.sm),
            SizedBox.square(
              dimension: 32,
              child: Center(child: MTDrawnCheck(color: p.ok)),
            ),
          ] else if (onCancel != null) ...[
            const SizedBox(width: MTSpace.sm),
            InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(MTRadius.chip),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.card.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(MTRadius.chip),
                ),
                child: Icon(Icons.close_rounded, size: 16, color: p.ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The still line of a task waiting its turn.
class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 5,
    width: double.infinity,
    child: CustomPaint(painter: _Dashes(color)),
  );
}

class _Dashes extends CustomPainter {
  const _Dashes(this.color);

  final Color color;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = 1.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + _dash).clamp(0, size.width - 1), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}
