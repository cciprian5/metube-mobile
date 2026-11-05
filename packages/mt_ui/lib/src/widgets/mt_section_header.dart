import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// A Wahaj section header: a Kufi title, a secondary line and a hairline
/// rule beneath. Rules instead of boxes (log §4).
class MTSectionHeader extends StatelessWidget {
  const MTSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.action,
  });

  final String title;
  final String? trailing;

  /// A small button at the end of the line, such as help for the section.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.xxs,
        MTSpace.xxs,
        MTSpace.xxs,
        MTSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: x.palette.line,
            width: MTThemeX.of(context).hairline,
          ),
        ),
      ),
      child: Row(
        // A button has no baseline to sit on, so a header with one centres
        // its line instead; a header without one is laid out as before.
        crossAxisAlignment: action == null
            ? CrossAxisAlignment.baseline
            : CrossAxisAlignment.center,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: text.titleMedium)),
          // The note has half the line at most, so on a narrow phone it
          // gives way to the title instead of pushing the row past the
          // edge; within its half it keeps to the end, or it would float
          // in the middle of a wide line.
          if (trailing != null)
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: x.palette.ink3),
                ),
              ),
            ),
          ?action,
        ],
      ),
    );
  }
}
