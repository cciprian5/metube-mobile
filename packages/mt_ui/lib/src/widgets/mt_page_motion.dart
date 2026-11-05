import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// Screen changes on the phones: the new page comes in a few points from
/// the reading side as it fades in, and the page underneath **steps back**
/// a little and dims, so it reads as still there. The way back is quicker
/// than the way in.
///
/// With Android's predictive back (14 and later), a swipe from the edge
/// shrinks the page under the finger with the page behind it in view:
/// let go and it completes, swipe back and it stays.
class MTSlidePageTransition extends PageTransitionsBuilder {
  const MTSlidePageTransition();

  /// How far the new page travels, in points. A long slide reads as a jump.
  static const double nudge = 8;

  /// How small a page gets at the far end of a back swipe.
  static const double swipeScale = 0.9;

  /// How far it follows the finger, as a share of the screen's width.
  static const double swipeShift = 0.08;

  /// The veil of the ground over the page that stepped back.
  static const double dim = 0.35;

  @override
  Duration get transitionDuration => MTMotion.page;

  @override
  Duration get reverseTransitionDuration => MTMotion.leave;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _BackSwipe(
      route: route,
      builder: (context, edge) => AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, child) => _frame(
          context,
          route: route,
          edge: edge,
          animation: animation,
          secondary: secondaryAnimation,
          child: child!,
        ),
        child: child,
      ),
    );
  }

  static double _curve(Animation<double> animation) =>
      (animation.status == AnimationStatus.reverse
              ? MTMotion.exit.flipped
              : MTMotion.entrance)
          .transform(animation.value);

  /// One shape of tree whatever the state, so the page underneath keeps
  /// its own state as the motion starts and ends.
  Widget _frame(
    BuildContext context, {
    required PageRoute<dynamic> route,
    required SwipeEdge? edge,
    required Animation<double> animation,
    required Animation<double> secondary,
    required Widget child,
  }) {
    // Stepping back while another page covers this one.
    final back = secondary.value == 0 ? 0.0 : _curve(secondary);
    final ground = MTThemeX.of(context).palette.bg;

    var opacity = 1.0;
    var shift = 0.0;
    var pulled = 0.0;
    if (edge != null && route.popGestureInProgress) {
      // Under the finger: the gesture drives the animation straight.
      pulled = 1 - animation.value;
      final toward = edge == SwipeEdge.left ? 1.0 : -1.0;
      shift = MediaQuery.sizeOf(context).width * swipeShift * pulled * toward;
      // Gone by the time the swipe has run its length.
      opacity = (animation.value / 0.3).clamp(0.0, 1.0);
    } else if (animation.value < 1) {
      final shown = _curve(animation);
      final rtl = Directionality.of(context) == TextDirection.rtl;
      shift = nudge * (rtl ? -1 : 1) * (1 - shown);
      opacity = shown;
    }

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(shift, 0),
        child: Transform.scale(
          scale: 1 - (1 - swipeScale) * pulled,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              MTCorners.mobile.sheet * pulled,
            ),
            clipBehavior: pulled > 0 ? Clip.antiAlias : Clip.none,
            child: ColoredBox(
              color: back > 0 ? ground : Colors.transparent,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  color: ground.withValues(alpha: dim * back),
                ),
                child: Transform.scale(
                  scale: 1 - (1 - MTMotion.recede) * back,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hands Android's back swipe to the route, as Flutter's own predictive
/// back builder does, so the page can follow the finger.
class _BackSwipe extends StatefulWidget {
  const _BackSwipe({required this.route, required this.builder});

  final PageRoute<dynamic> route;
  final Widget Function(BuildContext context, SwipeEdge? edge) builder;

  @override
  State<_BackSwipe> createState() => _BackSwipeState();
}

class _BackSwipeState extends State<_BackSwipe> with WidgetsBindingObserver {
  /// The edge the current swipe began at; kept until the next one so the
  /// page does not jump when the finger lifts and the swipe completes.
  SwipeEdge? _edge;

  /// False on a page that is built but hidden, such as a tab in the
  /// background or the screens under the player. Each navigator has its
  /// own current page, and only the one in view may answer a swipe.
  bool _inView = true;

  bool get _enabled =>
      _inView && widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_enabled) return false;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    setState(() => _edge = backEvent.swipeEdge);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) => widget
      .route
      .handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  @override
  void handleCommitBackGesture() => widget.route.handleCommitBackGesture();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inView = TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _edge);
}

/// Installed on `ThemeData.pageTransitionsTheme` in both apps.
const mtPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: MTSlidePageTransition(),
    TargetPlatform.iOS: MTSlidePageTransition(),
  },
);
