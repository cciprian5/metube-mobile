import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
///
/// [focus] marks the part as a whole, so the keyboard can be sent into it.
Widget inRegion(EmberRegion region, Widget child, {FocusNode? focus}) =>
    FocusTraversalOrder(
      order: NumericFocusOrder(region.index.toDouble()),
      child: FocusTraversalGroup(
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: focus == null
              ? child
              : Focus(focusNode: focus, skipTraversal: true, child: child),
        ),
      ),
    );

/// The window, whose parts take their turns in [EmberRegion]'s order.
Widget regionsInOrder(Widget child) =>
    FocusTraversalGroup(policy: OrderedTraversalPolicy(), child: child);

/// The content as a whole, so the keyboard can be sent into it.
final contentFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'content', skipTraversal: true);
  ref.onDispose(node.dispose);
  return node;
});

/// Puts the keyboard on the first control of the page just opened in
/// [content]. Opened from the search, focus had nowhere to return to, so a
/// screen reader went silent until Tab. The new page's own scope holds the
/// focus by then, while the page leaving is still drawn: its first control
/// is the one meant.
void focusFirstIn(FocusNode content) =>
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = FocusManager.instance.primaryFocus;
      final page = now is FocusScopeNode && now.ancestors.contains(content)
          ? now
          : content;
      // As Tab would: focused, and scrolled into view.
      if (page.traversalDescendants.firstOrNull case final first?) {
        FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
          first,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
