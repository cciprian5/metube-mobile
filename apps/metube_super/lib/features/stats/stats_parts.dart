import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// One bar of a breakdown: its name, what sets its length, what it says,
/// and what a tap opens.
typedef StatsBar = ({
  String label,
  int measure,
  String value,
  VoidCallback? onTap,
});

/// A white card with its small heading inside, as the settings groups.
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: MTSpace.md),
      // A surface of its own, so the rows' touch shows on the card.
      child: Material(
        color: x.palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MTRadius.card),
          side: BorderSide(color: x.palette.line, width: x.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MTSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title case final title?) ...[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall!
                      .copyWith(color: x.palette.ink3),
                ),
                const SizedBox(height: MTSpace.sm),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The library in a few figures, side by side with hairlines between.
class StatsFigures extends StatelessWidget {
  const StatsFigures({super.key, required this.figures});

  final List<({String value, String label})> figures;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, f) in figures.indexed) ...[
            if (i > 0) VerticalDivider(width: MTSpace.md, color: p.line),
            Expanded(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(f.value, style: text.titleLarge),
                  ),
                  Text(
                    f.label,
                    textAlign: TextAlign.center,
                    style: text.labelSmall!.copyWith(color: p.ink3),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A breakdown as bars in the action colour alone, the longest full.
class StatsBars extends StatelessWidget {
  const StatsBars({super.key, required this.rows});

  final List<StatsBar> rows;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final most = rows.fold(1, (m, r) => r.measure > m ? r.measure : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows)
          InkWell(
            onTap: r.onTap,
            borderRadius: BorderRadius.circular(MTRadius.field),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MTForeignText(
                          r.label,
                          maxLines: 1,
                          style: text.bodySmall!.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: MTSpace.sm),
                      // Half the line at most, so a large font squeezes
                      // the figures rather than the row past the edge.
                      Flexible(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            r.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall!.copyWith(color: p.ink3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MTSpace.xxs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MTRadius.pill),
                    child: SizedBox(
                      height: MTSpace.xxs,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: p.line),
                          FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: r.measure / most,
                            child: ColoredBox(color: p.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The months clips were added in, as columns: the oldest first, each
/// with its count above and its month below.
class StatsMonths extends StatelessWidget {
  const StatsMonths({super.key, required this.months});

  /// Oldest first.
  final List<({String label, int count})> months;

  static const double _tallest = 96;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final most = months.fold(1, (m, r) => r.count > m ? r.count : m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, month) in months.indexed) ...[
          if (i > 0) const SizedBox(width: MTSpace.sm),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${month.count}',
                  style: text.labelSmall!.copyWith(color: p.ink3).tabular,
                ),
                const SizedBox(height: MTSpace.xxs),
                Container(
                  height: _tallest * month.count / most,
                  decoration: BoxDecoration(
                    color: p.accent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(MTRadius.badge),
                    ),
                  ),
                ),
                const SizedBox(height: MTSpace.xxs),
                Text(
                  month.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall!.copyWith(color: p.ink3),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
