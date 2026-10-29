import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The ways of watching, side by side on one quiet ground. **Where their
/// words do not fit** (a small window, a large text size) they show their
/// glyphs alone, named in tooltips, rather than spill past the page.
class WatchGroup extends StatelessWidget {
  const WatchGroup({super.key, required this.children});

  final List<WatchChoice> children;

  /// The group's width with every word shown, measured at the text size in
  /// use.
  double _fullWidth(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    final scaler = MediaQuery.textScalerOf(context);
    var width = MTSpace.xxs;
    for (final choice in children) {
      final label = TextPainter(
        text: TextSpan(text: choice.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      width += label.width + MTSpace.lg + MTSpace.xxs + MTSpace.sm * 2;
      label.dispose();
    }
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return LayoutBuilder(
      builder: (context, box) {
        final words = _fullWidth(context) <= box.maxWidth;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: p.cardAlt,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(MTSpace.xxs / 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final choice in children)
                  WatchChoice(
                    label: choice.label,
                    icon: choice.icon,
                    onTap: choice.onTap,
                    on: choice.on,
                    words: words,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One way of watching: a glyph and a word; on, the page's own card under
/// it. Without its word, it says it in a tooltip.
class WatchChoice extends StatelessWidget {
  const WatchChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.on = false,
    this.words = true,
  });

  final String label;
  final MTIconData icon;
  final VoidCallback onTap;
  final bool on;
  final bool words;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final choice = Semantics(
      selected: on,
      button: true,
      label: words ? null : label,
      child: Material(
        color: on ? p.card : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.sm,
              vertical: MTSpace.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MTIcon(icon, size: MTSpace.lg, color: on ? p.ink : p.ink2),
                if (words) ...[
                  const SizedBox(width: MTSpace.xxs),
                  Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: on ? p.ink : p.ink2,
                      fontWeight: on ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return words ? choice : MTShortcutTooltip(message: label, child: choice);
  }
}
