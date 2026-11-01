import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'mt_polish.dart';

/// **Wahaj motion.** Every duration and distance comes from [MTMotion] in
/// `tokens.dart`; no literal values here.
///
/// **The second revision** (field report 2026-09-02: "the motion is
/// unbalanced, calm it down and make it smoother"). The first attempt
/// animated **every card as it was created**, and `SliverList.builder`
/// creates cards while you scroll, so every row entering the screen
/// started its own fade and slide. The result was a list that bounced
/// throughout the scroll, which is precisely what was reported.
///
/// The fix is structural, not cosmetic: **the screen enters once, its
/// items do not.** [MTRevealOnce] animates the whole block on first
/// appearance and then removes itself from the tree, leaving no
/// `AnimationController` and no work at all during scrolling.
///
/// The three remaining animations:
/// 1. [MTRevealOnce] for screen content entering once.
/// 2. [MTSlidePageTransition] (in `mt_page_motion.dart`) for screen
/// changes, following text direction.
/// 3. [MTAnimatedSwap] for content changing in place.

/// A **once-only** appearance for a block of content: a fade and a very
/// short offset.
///
/// When the animation ends it returns [child] bare. No `Transform` and no
/// `FadeTransition` are left in the tree, so scrolling afterwards costs
/// nothing.
class MTRevealOnce extends StatefulWidget {
  const MTRevealOnce({super.key, required this.child, this.delay});

  final Widget child;

  /// An optional delay for a light stagger between two blocks, never
  /// between dozens of items.
  final Duration? delay;

  @override
  State<MTRevealOnce> createState() => _MTRevealOnceState();
}

class _MTRevealOnceState extends State<MTRevealOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MTMotion.reveal,
  );

  /// **Built once rather than every frame**: a
  /// `CurvedAnimation` in `build` was created and abandoned sixty times a
  /// second without ever being disposed.
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: MTMotion.entrance,
  );

  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay == null || delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honours "reduce motion" in the system settings: an accessibility
    // requirement, not a refinement.
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// **The tree keeps its shape from the first frame to the last.** The
  /// widget used to replace the whole wrapper with
  /// `widget.child` when the animation ended, which changed the depth of
  /// every element and rebuilt the subtree: a scroll or a keystroke that
  /// began during the first 220ms was lost. Now the controller simply
  /// reaches 1, rebuilding stops on its own, and the shape is never
  /// touched.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curved,
    builder: (context, child) => Opacity(
      opacity: _curved.value,
      child: Transform.translate(
        offset: Offset(0, MTMotion.slideNudge * (1 - _curved.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// Content changing in place with a cross-fade, never a slide: the element
/// did not move, it changed.
///
/// The child needs a key that changes with its content.
class MTAnimatedSwap extends StatelessWidget {
  const MTAnimatedSwap({
    super.key,
    required this.child,
    this.duration = MTMotion.tap,
    this.alignment = Alignment.center,
    this.blur = false,
  });

  final Widget child;
  final Duration duration;

  /// Where the two overlap while they cross, such as the start of a line
  /// of text.
  final AlignmentGeometry alignment;

  /// A light blur on whichever is fading, for text: two titles crossing
  /// sharp read as one garbled line.
  final bool blur;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: mtMotionDuration(context, duration),
    switchInCurve: MTMotion.entrance,
    switchOutCurve: MTMotion.exit,
    layoutBuilder: (current, previous) =>
        Stack(alignment: alignment, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: blur
          ? AnimatedBuilder(
              animation: animation,
              builder: (context, child) => ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 2 * (1 - animation.value),
                  sigmaY: 2 * (1 - animation.value),
                ),
                child: child,
              ),
              child: child,
            )
          : child,
    ),
    child: child,
  );
}

/// Page changes on a computer: **a fade-through**, the old page gone first
/// and the new one rising a few points as it fades in.
///
/// Flutter's Windows default zooms the new page out of a dark scrim from
/// a snapshot, which inside a shell reads as a dark frame and a thin line
/// round a shrinking page. Here nothing scales, nothing is snapshotted and
/// the two pages barely overlap, so a playing picture never doubles.
class MTDesktopPageTransition extends PageTransitionsBuilder {
  const MTDesktopPageTransition();

  /// Where the old page is gone and the new one starts to show.
  static const double handOver = 0.35;

  @override
  Duration get transitionDuration => MTMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final enter = CurvedAnimation(
      parent: animation,
      curve: const Interval(handOver, 1, curve: MTMotion.entrance),
    );
    final leave = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0, handOver, curve: MTMotion.exit),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([enter, leave]),
      builder: (context, child) => Opacity(
        opacity: enter.value * (1 - leave.value),
        child: Transform.translate(
          offset: Offset(0, MTMotion.slideNudge * (1 - enter.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
