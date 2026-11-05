import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../theme/mt_theme_controls.dart';
import 'mt_desktop_app.dart';

/// The card ground: selection is a steady colour, while a highlight is a
/// colour that **fades out by itself**.
///
/// `TweenAnimationBuilder` is enough with no state: it runs from 1 to 0
/// once on the first build, so the highlight extinguishes itself even if
/// the caller forgets to clear it. The list card and the grid card share
/// it so the meaning of the colour cannot drift between the two.
///
/// On the phones a selection is the ink's veil, as every chosen thing in
/// their chrome is (log §4, 2026-10-31); the accent's tint is kept for the
/// highlight, which marks an arrival. Ember keeps its own tint.
class MTHighlightSurface extends StatelessWidget {
  const MTHighlightSurface({
    super.key,
    required this.selected,
    required this.highlighted,
    required this.child,
    this.borderRadius,
  });

  static const glowFade = Duration(milliseconds: 2400);

  final bool selected;
  final bool highlighted;
  final Widget child;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final chosen = MTDesktopApp.isDesktop(context)
        ? p.accentSoft
        : mtSelectedFill(p);
    final base = selected ? chosen : Colors.transparent;
    final shape = borderRadius == null
        ? null
        : RoundedRectangleBorder(borderRadius: borderRadius!);
    if (!highlighted) {
      return Material(color: base, shape: shape, child: child);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: glowFade,
      curve: Curves.easeOutCubic,
      builder: (context, t, inner) => Material(
        color: Color.lerp(base, p.accentSoft, t),
        shape: shape,
        child: inner,
      ),
      child: child,
    );
  }
}
