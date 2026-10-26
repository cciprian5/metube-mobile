import 'package:flutter/widgets.dart';

/// The window's parts, **in the order Tab visits them**: the places, the
/// bar above the content, the content, the side panel, the player, and
/// the window's own buttons last. Left to itself, Flutter goes by where
/// each control sits, so Tab started in the middle of the content and
/// reached the search box after everything else. Each part is a group and
/// has its number: either alone keeps the parts whole and in turn, both
/// together whatever the layout becomes.
enum EmberRegion { sidebar, contentBar, content, panel, playerBar, titleBar }

/// One part of the window: Tab goes through all of it before the next.
///
/// Each part is also its own node for a screen reader. The content holds a
/// navigator, and every page there lies over a modal barrier that hides
/// from screen readers whatever was painted before it in the same node:
/// without these walls the title bar, sidebar and content bar vanished.
/// Explicit children, so the wall does not fold its loose labels into one.
Widget inRegion(EmberRegion region, Widget child) => FocusTraversalOrder(
  order: NumericFocusOrder(region.index.toDouble()),
  child: FocusTraversalGroup(
    child: Semantics(container: true, explicitChildNodes: true, child: child),
  ),
);

/// The window, whose parts take their turns in [EmberRegion]'s order.
Widget regionsInOrder(Widget child) =>
    FocusTraversalGroup(policy: OrderedTraversalPolicy(), child: child);
