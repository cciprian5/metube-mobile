import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// A count on a button: a small square in the accent, not Material's red
/// dot. Red is kept for errors, so a queue of three never reads as an alarm.
class MTBadge extends StatelessWidget {
  const MTBadge({super.key, required this.count, this.max = 99});

  final int count;

  /// Larger counts show as "99+".
  final int max;

  static const _side = 17.0;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final label = count > max ? '$max+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: _side, minHeight: _side),
      padding: const EdgeInsets.symmetric(horizontal: MTSpace.xxs),
      // No `alignment` on the Container: it would make the badge as wide
      // as whatever holds it. Centred inside its own size instead.
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: BorderRadius.circular(MTCorners.desktop.box),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          // A count reads left to right in Arabic too: "99+", not "+99".
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: p.onAccent,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
