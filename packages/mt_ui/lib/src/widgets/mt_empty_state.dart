import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// A Wahaj empty state: an honest heading in Kufi, the next step in one
/// sentence, and at most one action in the ink.
///
/// **No icon on a disc** (log §4, 2026-10-31): an emblem over an empty page
/// was one of the marks of a generated screen, and the accent on its action
/// competed with the screen's own add button.
class MTEmptyState extends StatelessWidget {
  const MTEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MTSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: MTSpace.xs),
            Text(
              message,
              style: text.bodyMedium!.copyWith(color: x.palette.ink2),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: MTSpace.md),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
