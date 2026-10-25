import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// A tooltip that teaches the keyboard: the label, then the shortcut in a
/// small key cap ("Download to this computer  Ctrl+D"). The card itself
/// comes from the desktop theme.
class MTShortcutTooltip extends StatelessWidget {
  const MTShortcutTooltip({
    super.key,
    required this.message,
    this.shortcut,
    required this.child,
  });

  final String message;

  /// Shown as written, for example "Ctrl+D". Null shows the label alone.
  final String? shortcut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final style = TooltipTheme.of(context).textStyle;
    final key = shortcut;
    return Tooltip(
      richMessage: TextSpan(
        style: style,
        children: [
          TextSpan(text: message),
          if (key != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                margin: const EdgeInsetsDirectional.only(start: MTSpace.sm),
                padding: const EdgeInsets.symmetric(horizontal: MTSpace.xxs),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: p.miniInk.withValues(alpha: 0.3),
                    width: MTThemeX.of(context).hairline,
                  ),
                  borderRadius: BorderRadius.circular(MTCorners.desktop.box),
                ),
                child: Text(
                  key,
                  style: style?.copyWith(
                    fontSize: Theme.of(context).textTheme.labelSmall!.fontSize,
                    color: p.miniInk.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
      child: child,
    );
  }
}
