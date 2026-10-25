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
Widget inRegion(EmberRegion region, Widget child) => FocusTraversalOrder(
  order: NumericFocusOrder(region.index.toDouble()),
  child: FocusTraversalGroup(child: child),
);

/// The window, whose parts take their turns in [EmberRegion]'s order.
Widget regionsInOrder(Widget child) =>
    FocusTraversalGroup(policy: OrderedTraversalPolicy(), child: child);
