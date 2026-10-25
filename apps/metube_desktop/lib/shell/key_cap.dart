import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// A key as the keyboard prints it ("Ctrl K", "Space"), in a hairline
/// frame. Always left to right: keys read the same in either language.
class KeyCap extends StatelessWidget {
  const KeyCap({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: p.line2),
          borderRadius: BorderRadius.circular(MTCorners.desktop.box),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpace.xs,
            vertical: MTSpace.xxs / 2,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: p.ink3),
          ),
        ),
      ),
    );
  }
}
