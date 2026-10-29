import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

/// One row of a breakdown: its name, the amount its bar is drawn to, and
/// that amount as words.
typedef StatsBar = ({String label, int measure, String value});

/// **A breakdown as bars**, one series in the accent: the name, a thin bar
/// against the largest, and the figures in ink beside it. The figures are
/// the reading; the bar only shows proportion, so the rows are a table to a
/// screen reader too.
class StatsBars extends StatelessWidget {
  const StatsBars({super.key, required this.rows});

  final List<StatsBar> rows;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final largest = rows.fold(1, (most, r) => math.max(most, r.measure));
    return Column(
      children: [
        for (final row in rows)
          Semantics(
            label: '${row.label}: ${row.value}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: mtTextDirectionOf(
                        row.label,
                        Directionality.of(context),
                      ),
                      textAlign: TextAlign.start,
                      style: text.bodyMedium?.copyWith(color: p.ink),
                    ),
                  ),
                  const SizedBox(width: MTSpace.md),
                  Expanded(flex: 4, child: _Bar(share: row.measure / largest)),
                  const SizedBox(width: MTSpace.md),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.tabular.copyWith(color: p.ink2),
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

/// A thin bar on a quiet track, rounded at both ends, grown from the start.
class _Bar extends StatelessWidget {
  const _Bar({required this.share});

  final double share;

  static const double _thickness = 6;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final round = BorderRadius.circular(_thickness / 2);
    return Container(
      height: _thickness,
      decoration: BoxDecoration(color: p.cardAlt, borderRadius: round),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        // Never thinner than its own height, so a small share still shows.
        widthFactor: share.clamp(0, 1),
        child: Container(
          constraints: const BoxConstraints(minWidth: _thickness),
          decoration: BoxDecoration(color: p.accent, borderRadius: round),
        ),
      ),
    );
  }
}

/// The library's figures in **one frame split by hairlines**, as many to a
/// row as fit. Four or five boxes of their own, each with its border and
/// corners, were one of the marks of a generated dashboard.
class StatsFigures extends StatelessWidget {
  const StatsFigures({super.key, required this.figures});

  final List<StatsTile> figures;

  /// Wide enough that five figures line up in two rows at most.
  static const double _minWidth = 160;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final rule = BorderSide(
      color: p.line,
      width: MTThemeX.of(context).hairline,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final across = (box.maxWidth / _minWidth).floor().clamp(
          1,
          figures.length,
        );
        final rows = [
          for (var i = 0; i < figures.length; i += across)
            figures.sublist(i, (i + across).clamp(0, figures.length)),
        ];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(MTCorners.desktop.card),
            border: Border.fromBorderSide(rule),
          ),
          child: Column(
            children: [
              for (final (r, row) in rows.indexed)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: r == 0 ? BorderSide.none : rule),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < across; c++)
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: BorderDirectional(
                                  start: c == 0 ? BorderSide.none : rule,
                                ),
                              ),
                              child: c < row.length
                                  ? row[c]
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One of the library's figures: the number large, what it counts beneath.
class StatsTile extends StatelessWidget {
  const StatsTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(MTSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: text.headlineSmall?.tabular),
          const SizedBox(height: MTSpace.xxs),
          Text(label, style: text.labelMedium?.copyWith(color: p.ink3)),
        ],
      ),
    );
  }
}

/// What may deserve a look, with the first few clips it means; a click
/// opens a clip's page. Nothing is deleted from here.
class StatsSuggestion extends StatelessWidget {
  const StatsSuggestion({
    super.key,
    required this.title,
    required this.meta,
    required this.lead,
    required this.items,
    required this.detail,
    required this.onOpen,
  });

  final String title;

  /// How many, and how much room.
  final String meta;

  /// What the clips listed are: the largest, the newest.
  final String lead;
  final List<LibraryItem> items;
  final String? Function(LibraryItem) detail;
  final ValueChanged<LibraryItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleSmall?.copyWith(color: p.ink)),
          Text(meta, style: text.bodySmall?.copyWith(color: p.ink3)),
          const SizedBox(height: MTSpace.xs),
          Text(lead, style: text.labelSmall?.copyWith(color: p.ink3)),
          for (final item in items)
            Semantics(
              button: true,
              child: InkWell(
                onTap: () => onOpen(item),
                borderRadius: BorderRadius.circular(MTCorners.desktop.thumb),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: MTSpace.xs,
                    horizontal: MTSpace.xxs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: mtTextDirectionOf(
                            item.title,
                            Directionality.of(context),
                          ),
                          style: text.bodyMedium?.copyWith(color: p.ink2),
                        ),
                      ),
                      if (detail(item) case final line?) ...[
                        const SizedBox(width: MTSpace.md),
                        Text(
                          line,
                          style: text.labelSmall?.tabular.copyWith(
                            color: p.ink3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
