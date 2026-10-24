import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The Wahaj section header as the phones draw it (a Kufi title, a quiet
/// line at the end, a hairline beneath), except that **the end line gives
/// way**: in a window at a large font it shortens instead of pushing the
/// row past its edge. The phones' header keeps its own rules.
class EmberSectionHeader extends StatelessWidget {
  const EmberSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.action,
  });

  final String title;
  final String? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.xxs,
        MTSpace.xxs,
        MTSpace.xxs,
        MTSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium,
            ),
          ),
          if (trailing case final line?)
            Flexible(
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: text.bodySmall?.copyWith(color: p.ink3),
              ),
            ),
          // A button keeps its size; the two texts are what give way.
          ?action,
        ],
      ),
    );
  }
}
